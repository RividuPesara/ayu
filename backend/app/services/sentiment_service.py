import logging
import os
import re

from app.services.language_service import normalize_to_english

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
JOY_WORDS = {
    'happy','happiness','joy','joyful','excited','excitement','amazing','wonderful',
    'fantastic','great','love','loved','grateful','gratitude','blessed','thrilled',
    'delighted','ecstatic','overjoyed','proud','celebrate','celebrating','smiling',
    'laughing','laugh','beautiful','incredible','awesome','lucky','thankful',
    'promoted','promotion','scholarship','accepted','engaged','proposal','born',
    'baby','married','wedding','vacation','holiday','trip','surprise','gift',
    'moon','unstoppable','alive','peace','peaceful','magical','crossed','finish',
    'line','milestone','achievement','achieved','dream','worth','penny','saved',
    'cheering','dancing','danced','winning','won','passed','congratulations',
    'glowing','beaming','radiant','light','smile','grinning','grin','elated',
    'content','fulfilling','fulfilled','meaningful','rewarding','rewarded',
}

ANXIETY_WORDS = {
    'anxious','anxiety','worry','worried','worrying','panic','panicking','fear',
    'fearful','terrified','terrifying','terror','dread','dreading','nervous',
    'catastrophize','catastrophizing','overthink','overthinking','racing',
    'trembling','shaking','freeze','frozen','avoid','avoidance','scared',
    'breathe','chest','tightens','tighten','attacks','attack','scenarios',
    'convinced','wrong','shake','judged','highways','losing','control',
    'smaller','triggered','trigger','worrying','terrible','cancelled',
    'interviews','crowd','crowded','spiral','spiraling','restless','uneasy',
    'apprehensive','tense','tension','phobia','obsess','obsessing',
    'checking','locks','ruminate','ruminating','sleepless','insomnia',
    'heart','pounding','sweating','sweat','nauseous','nausea','faint',
}

STRESS_WORDS = {
    'stress','stressed','stressful','burnout','burned','overwhelmed','overloaded',
    'exhausted','exhaustion','pressure','deadline','workload','furious','angry',
    'anger','irritable','irritated','snapping','frustrated','frustration',
    'relentless','piling','humiliated','juggling','rent','cover','barely',
    'syllabus','missed','launch','client','sixteen','edge','temper','aches',
    'breaking','crushing','meetings','running','empty','behind','overdue',
    'manager','boss','colleague','fired','layoff','debt','bills','financial',
    'screaming','yelling','yelled','slammed','snapped','boiling','fuming',
    'seething','livid','outraged','grinding','drained','depleted','stretched',
    'pulled','pushed','collapsing','crumbling','falling','apart','cope','coping',
}

DEPRESSION_WORDS = {
    'depressed','depression','hopeless','hopelessness','empty','numb','worthless',
    'useless','lonely','loneliness','isolated','isolation','crying','cried',
    'sadness','sad','miserable','darkness','dark','pointless','meaningless',
    'void','hollow','broken','shattered','defeated','lost','invisible',
    'disconnected','ghost','drifting','faking','fake','mask','pretend',
    'exhausted','heavy','sinking','drowning','suffocating','trapped','stuck',
    'failure','failed','disappoint','disappointing','ashamed','shame','guilt',
    'regret','nothingness','bleak','grey','gray','colorless','lifeless',
    'apathy','apathetic','withdrawn','detached','unmotivated','unmoved',
}

SUICIDAL_WORDS = {
    'suicidal','suicide','die','dying','dead','death','kill','goodbye','note',
    'plan','end','bridge','pills','overdose','cut','cutting','harm','pain',
    'method','ready','disappear','disappeared','letgo','peace','relieved',
    'farewell','arranged','neighbor','dog','stopping','almost',
    'tonight','night','stockpiling','researched','methods','reason','stay',
    'birthday','unbearable','terminal','decided','terms','deeper','wakeup',
    'morning','hoped','awake','knife','rope','jump','jumped','ledge','final',
}

# negation words to flip meaning
NEGATION_WORDS = {
    'not','never','no','nothing','nobody','nowhere','neither','nor','none',
    'cannot','cant','wont','wouldnt','shouldnt','couldnt','dont','doesnt',
    'didnt','hasnt','havent','hadnt','isnt','arent','wasnt','werent',
}
# keywords that immediately indicate crisis risk
KEYWORD_CRISIS = {
    'kill myself', 'end my life', 'want to die', 'going to kill',
    'suicide', 'overdose', 'goodbye forever', 'end it all',
    'no reason to live', 'better off dead', 'cant go on',
    'take my own life', 'dont want to be here', 'ready to die',
    'life isnt worth', 'nothing left to live for', 'final goodbye',
    'jumping off', 'hanging myself', 'cut my wrists', 'slit my',
    'self harm', 'hurt myself badly', 'harm myself',
    'want it to end', 'ready to go', 'cant take it anymore',
    'everyone better without me', 'burden to everyone',
    'world without me', 'stockpiling pills', 'writing goodbye',
    'suicide note', 'plan to end', 'wont be here tomorrow',
    'final message', 'kill me', 'wish i was dead',
    'shouldnt exist', 'disappear forever', 'cease to exist',
}

# Sinhala crisis keywords this is scanned on the original text before translation
KEYWORD_CRISIS_SINHALA = {
    'මරණය', 'මැරෙනවා', 'මැරිලා', 'මැරෙන්න', 'ජීවිතේ අවසන්', 'ජීවත් වෙන්න බෑ', 
    'ජීවිතය නැති කරගන්නවා', 'සියදිවි නසාගන්නවා', 'දිවි නසාගන්නවා', 'ගෙල වැළලා', 
    'දිවි තොර කරගන්නවා', 'මම ඉන්නේ නෑ', 'හැමෝටම හොඳයි මම නැතිනම්', 'සමුගන්නවා',
    'යන්න යනවා', 'අන්තිම ලිපිය', 'අන්තිම පණිවිඩය', 'මරණ පරීක්ෂණය',
    'විෂ බොනවා', 'වස බොනවා', 'වස පෙති', 'පෙති බොනවා', 'බෙහෙත් බොනවා',
    'කෝච්චියට පනිනවා', 'දුම්රියට පැනලා', 'ගඟට පනිනවා', 'වැවට පනිනවා', 
    'ගලෙන් පැනලා', 'උඩින් පනිනවා', 'එල්ලෙනවා', 'ලණුවක්', 'ගිනි තියාගන්නවා', 
    'කපාගන්නවා', 'අත කපාගන්නවා', 'තුවාල කරගන්නවා', 'ලේ ගලවනවා'
}

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
_classes: list[str] = []
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
    logger.info("Sentiment models loaded. Classes: %s", _classes)


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


def _wordnet_pos(treebank_tag: str):
    tag_map = {'J': wordnet.ADJ, 'V': wordnet.VERB, 'R': wordnet.ADV}
    return tag_map.get(treebank_tag[0].upper() if treebank_tag else 'N', wordnet.NOUN)


def lemmatize_text(text: str) -> str:
    # pos_tag called once for the full token list, not once per word
    tokens = [t for t in word_tokenize(text) if t.isalpha()]
    if not tokens:
        return ''
    tagged = nltk.pos_tag(tokens)
    return ' '.join(_lemmatizer.lemmatize(tok, _wordnet_pos(tag)) for tok, tag in tagged)

# Feature engineering
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


def _build_features_for_text(text: str) -> np.ndarray:
    # extract numerical features directly from a single text string — no pandas overhead
    return np.array([[
        len(text),
        len(sent_tokenize(text)),
        len(text.split()),
        _avg_word_length(text),
        _exclamation_count(text),
        _question_count(text),
        _caps_ratio(text),
        _has_negation(text),
        _count_lexicon(text, JOY_WORDS),
        _count_lexicon(text, ANXIETY_WORDS),
        _count_lexicon(text, STRESS_WORDS),
        _count_lexicon(text, DEPRESSION_WORDS),
        _count_lexicon(text, SUICIDAL_WORDS),
    ]], dtype=float)


def build_features(df: pd.DataFrame) -> np.ndarray:
    # kept for any external callers; delegates to the single-text helper
    return np.vstack([_build_features_for_text(str(t)) for t in df['text']])


def _preprocess(text: str, clean: str | None = None):
    # clean and convert text into model input; accepts pre-computed clean string to avoid double lemmatization
    if clean is None:
        clean = lemmatize_text(remove_patterns(fix_encoding(text)))
    uni = _tfidf_uni.transform([clean])
    bi = _tfidf_bi.transform([clean])
    num = csr_matrix(_build_features_for_text(text))
    return hstack([uni, bi, num])


def predict_label(text: str, clean: str | None = None) -> dict:
    # run all models and combine predictions  and accepts precomputed clean string to avoid double lemmatization
    X = _preprocess(text, clean=clean)

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
    # detect crisis using keyword and model; lemmatize once and reuse across predict_label and has_medical_vocabulary

    # scan original Sinhala text for crisis phrases before any translation
    sinhala_keyword_hit = any(kw in user_text for kw in KEYWORD_CRISIS_SINHALA)

    # translate to English if needed but english input is returned as it is
    english_text, detected_lang = normalize_to_english(user_text)

    lower = english_text.lower()
    keyword_hit = sinhala_keyword_hit or any(kw in lower for kw in KEYWORD_CRISIS)

    clean = lemmatize_text(remove_patterns(fix_encoding(english_text)))
    model_detail = predict_label(english_text, clean=clean)
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
        'detected_lang': detected_lang,
        'english_text': english_text,
        'emotion_label': model_label,
        'safety_flag': safety_flag,
        'triggered_by': triggered_by,
        'keyword_crisis_match': keyword_hit,
        'model_crisis_match': model_crisis,
        'suicidal_confidence': suicidal_score,
        'model_scores': model_detail.get('scores', {}),
        'model_detail': model_detail,
        '_clean': clean,
    }


def has_medical_vocabulary(query: str, clean: str | None = None) -> bool:
    # check if query contains medical terms from training vocabulary; accepts pre-computed clean string
    if clean is None:
        clean = lemmatize_text(remove_patterns(fix_encoding(query)))
    vec = _tfidf_uni.transform([clean])
    return vec.nnz > 0