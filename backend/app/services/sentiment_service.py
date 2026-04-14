import logging
import os
import re

import ftfy
import joblib
import nltk
import numpy as np
import pandas as pd
from nltk.corpus import wordnet
from nltk.stem import WordNetLemmatizer
from nltk.tokenize import sent_tokenize, word_tokenize
from scipy.sparse import csr_matrix, hstack

logger = logging.getLogger(__name__)

# download required nltk data if missing
for _pkg in ("punkt", "wordnet", "averaged_perceptron_tagger", "punkt_tab", "averaged_perceptron_tagger_eng"):
    try:
        nltk.data.find(f"tokenizers/{_pkg}" if _pkg.startswith("punkt") else f"taggers/{_pkg}")
    except LookupError:
        nltk.download(_pkg, quiet=True)

# emotion word lists used for rule based features
JOY_WORDS = {...}
ANXIETY_WORDS = {...}
STRESS_WORDS = {...}
DEPRESSION_WORDS = {...}
SUICIDAL_WORDS = {...}

# negation words to flip meaning
NEGATION_WORDS = {...}

# keywords that immediately indicate crisis risk
KEYWORD_CRISIS = {...}

# threshold for suicidal confidence from model
SUICIDAL_CRISIS_THRESHOLD = 0.65

# weights for models
MODEL_WEIGHTS = {
    'lr': 0.50,
    'bnb': 0.20,
    'xgb': 0.30,
}

# model variables loaded once at startup
_models_loaded = False
_lr_model = None
_bnb_model = None
_xgb_model = None
_tfidf_uni = None
_tfidf_bi = None
_le = None
_classes = []
_lemmatizer = WordNetLemmatizer()


def _load_models(model_dir: str) -> None:
    global _models_loaded, _lr_model, _bnb_model, _xgb_model
    global _tfidf_uni, _tfidf_bi, _le, _classes

    if _models_loaded:
        return

    logger.info("Loading models from %s", model_dir)

    _lr_model = joblib.load(os.path.join(model_dir, "lr_model.pkl"))
    _bnb_model = joblib.load(os.path.join(model_dir, "bnb_model.pkl"))
    _xgb_model = joblib.load(os.path.join(model_dir, "xgb_model.pkl"))

    vectorizers = joblib.load(os.path.join(model_dir, "vectorizer.pkl"))
    _tfidf_uni = vectorizers["unigram"]
    _tfidf_bi = vectorizers["bigram"]

    _le = joblib.load(os.path.join(model_dir, "label_encoder.pkl"))
    _classes = list(_le.classes_)

    _models_loaded = True


def initialize_sentiment_service(model_dir: str) -> None:
    # load models at startup
    _load_models(model_dir)


def fix_encoding(text: str) -> str:
    # fix broken text encoding and remove control characters
    if not isinstance(text, str):
        return text
    text = ftfy.fix_text(text)
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]', '', text)
    text = re.sub(r' {2,}', ' ', text)
    return text.strip()


def remove_patterns(text: str) -> str:
    # clean urls mentions and punctuation
    text = str(text).lower()
    text = re.sub(r'http[s]?://\S+', '', text)
    text = re.sub(r'\[.*?\]\(.*?\)', '', text)
    text = re.sub(r'@\w+', '', text)
    text = re.sub(r'[^\w\s]', '', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def _get_wordnet_pos(word: str):
    # map pos tag for better lemmatization
    tag = nltk.pos_tag([word])[0][1][0].upper()
    tag_map = {'J': wordnet.ADJ, 'V': wordnet.VERB, 'R': wordnet.ADV}
    return tag_map.get(tag, wordnet.NOUN)


def lemmatize_text(text: str) -> str:
    # convert words to base form
    tokens = word_tokenize(text)
    result = []
    for token in tokens:
        if not token.isalpha():
            continue
        pos = _get_wordnet_pos(token)
        lemma = _lemmatizer.lemmatize(token, pos)
        result.append(lemma)
    return ' '.join(result)


def _count_lexicon(text: str, lexicon: set) -> int:
    # count emotion words in text
    tokens = set(text.lower().split())
    return len(tokens & lexicon)


def _has_negation(text: str) -> int:
    # check if negation words exist
    tokens = set(text.lower().split())
    return int(bool(tokens & NEGATION_WORDS))


def _exclamation_count(text: str) -> int:
    return text.count('!')


def _question_count(text: str) -> int:
    return text.count('?')


def _caps_ratio(text: str) -> float:
    # ratio of uppercase letters
    letters = [c for c in text if c.isalpha()]
    if not letters:
        return 0.0
    return sum(1 for c in letters if c.isupper()) / len(letters)


def _avg_word_length(text: str) -> float:
    # average word length in sentence
    words = text.split()
    if not words:
        return 0.0
    return sum(len(w) for w in words) / len(words)


def build_features(df: pd.DataFrame) -> np.ndarray:
    # extract numerical features from text
    features = pd.DataFrame()
    features['num_chars'] = df['text'].str.len()
    features['num_sentences'] = df['text'].apply(lambda x: len(sent_tokenize(str(x))))
    features['num_words'] = df['text'].str.split().str.len()
    features['avg_word_len'] = df['text'].apply(_avg_word_length)
    features['exclamation'] = df['text'].apply(_exclamation_count)
    features['question'] = df['text'].apply(_question_count)
    features['caps_ratio'] = df['text'].apply(_caps_ratio)
    features['has_negation'] = df['text'].apply(_has_negation)

    # emotion scores from lexicons
    features['joy_score'] = df['text'].apply(lambda x: _count_lexicon(x, JOY_WORDS))
    features['anxiety_score'] = df['text'].apply(lambda x: _count_lexicon(x, ANXIETY_WORDS))
    features['stress_score'] = df['text'].apply(lambda x: _count_lexicon(x, STRESS_WORDS))
    features['depression_score'] = df['text'].apply(lambda x: _count_lexicon(x, DEPRESSION_WORDS))
    features['suicidal_score'] = df['text'].apply(lambda x: _count_lexicon(x, SUICIDAL_WORDS))

    return features.values


def _preprocess(text: str):
    # clean and convert text into model input
    clean = lemmatize_text(remove_patterns(fix_encoding(text)))
    row = pd.DataFrame([{'text': text}])
    uni = _tfidf_uni.transform([clean])
    bi = _tfidf_bi.transform([clean])
    num = csr_matrix(build_features(row))
    return hstack([uni, bi, num])


def predict_label(text: str) -> dict:
    # run all models and combine predictions
    X = _preprocess(text)

    lr_proba = _lr_model.predict_proba(X)[0]
    xgb_proba = _xgb_model.predict_proba(X)[0]

    bnb_raw = _bnb_model.predict(X)[0]
    bnb_vote = np.zeros(len(_classes))
    bnb_vote[bnb_raw] = 1.0

    combined = (
        MODEL_WEIGHTS['lr'] * lr_proba +
        MODEL_WEIGHTS['bnb'] * bnb_vote +
        MODEL_WEIGHTS['xgb'] * xgb_proba
    )

    final_idx = np.argmax(combined)
    final_label = _le.inverse_transform([final_idx])[0]

    return {
        'lr_pred': _le.inverse_transform([np.argmax(lr_proba)])[0],
        'bnb_pred': _le.inverse_transform([bnb_raw])[0],
        'xgb_pred': _le.inverse_transform([np.argmax(xgb_proba)])[0],
        'final_label': final_label,
        'scores': dict(zip(_classes, combined.round(4))),
    }


def analyze_safety(user_text: str) -> dict:
    # detect crisis using keyword and model
    lower = user_text.lower()
    keyword_hit = any(kw in lower for kw in KEYWORD_CRISIS)

    model_detail = predict_label(user_text)
    model_label = model_detail['final_label']
    suicidal_score = model_detail['scores'].get('Suicidal', 0)

    model_crisis = (model_label == 'Suicidal' and suicidal_score >= SUICIDAL_CRISIS_THRESHOLD)

    safety_flag = 'crisis' if (keyword_hit or model_crisis) else 'non_crisis'

    if keyword_hit and model_crisis:
        triggered_by = 'both'
    elif keyword_hit:
        triggered_by = 'keyword'
    elif model_crisis:
        triggered_by = 'model'
    else:
        triggered_by = 'none'

    return {
        'user_message': user_text,
        'emotion_label': model_label,
        'safety_flag': safety_flag,
        'triggered_by': triggered_by,
        'keyword_crisis_match': keyword_hit,
        'model_crisis_match': model_crisis,
        'suicidal_confidence': suicidal_score,
        'model_scores': model_detail.get('scores', {}),
        'model_detail': model_detail,
    }


def has_medical_vocabulary(query: str) -> bool:
    # check if query contains medical terms from training vocabulary
    clean = lemmatize_text(remove_patterns(fix_encoding(query)))
    vec = _tfidf_uni.transform([clean])
    return vec.nnz > 0