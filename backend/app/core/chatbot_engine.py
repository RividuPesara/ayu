import json
import logging
import os
import random
import re
from collections import Counter
from langchain_chroma import Chroma
from langchain_core.documents import Document
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter

from app.services.sentiment_service import (analyze_safety, has_medical_vocabulary,)

logger = logging.getLogger(__name__)

# Ayu system prompt
SYSTEM_PROMPT = """You are Ayu, someone who genuinely cares about people going through cancer treatment in Sri Lanka.

Think of yourself as a supportive friend who happens to know a lot about cancer care in Sri Lanka. You listen, you understand, and you share what you know when it helps.

How you talk:
- Keep it real and conversational, like texting a friend
- Do NOT greet like say 'Hey', 'Hi', or 'Hello' if the conversation is already ongoing
- Short responses usually work better, unless someone needs details
- Ask follow-up questions when it makes sense, not every single time
- Sometimes just listening is enough, you do not always need to give advice
- Use everyday Sinhala-English words when natural (like saying Apeksha instead of always saying the full hospital name)
- Never sound like a brochure or robot

What you know:
- Cancer treatment in Sri Lanka, especially government hospitals
- Practical stuff like transport, costs, what to expect
- Emotional support, because this is hard
- When to point people to actual doctors (you are not one)

What you do not do:
- Diagnose anything medical
- Guarantee treatment outcomes
- Make people feel stupid for being scared or confused
- Give long lectures unless they ask for details
- Say things like I do not have access to real-time information or As an AI

Safety first:
- If someone is in crisis, give them 1990 (ambulance) and keep them talking
- Be honest when you do not know something

STRICT MEMORY RULE — this overrides everything else:
You may sometimes be given BACKGROUND MEMORY about this person from past sessions.
NEVER mention, reference, or allude to anything from that memory unless the user brings it up first in THIS conversation.
If the user says "hi" or starts small talk, respond only to what they just said. Pretend you do not remember anything from before.
The memory is only for silent context — to adjust your tone and give accurate medical advice — NOT to bring up past events."""

CRISIS_HARDCODED_PREFIX = "I'm here with you."

CRISIS_FALLBACK_TEMPLATES = [
    "I'm here with you right now. If you're in danger, call 1990. Are you safe?",
    "I'm here. If you need help right now, call 1990. Can you tell me if you're somewhere safe?",
    "I'm with you. If you're thinking of hurting yourself, call 1990 now. Is someone near you?",
]

# Excluded from lexical keyword matching
DEFAULT_STOP_WORDS = {
    "where", "is", "the", "a", "an", "of", "to", "in", "for", "on", "at",
    "what", "which", "who", "when", "why", "how", "are", "was", "were", "be",
}

# Global singletons used by the chatbot engine these are initialized once during FastAPI startup
_engine_initialized = False
_embeddings = None
_vectorstore = None
_llm = None
_split_docs: list[Document] = []


def initialize_chatbot_engine(
    gemini_api_key: str,
    chroma_db_dir: str,
    knowledge_base_path: str,
    hf_token: str | None = None,
) -> None:
    #Load embeddings, rebuild ChromaDB index from the knowledge base JSON,and initialise the Gemini LLM once 
    
    global _engine_initialized, _embeddings, _vectorstore, _llm, _split_docs

    if _engine_initialized:
        return

    logger.info("Initialising chatbot engine")

    # Set HF token
    if hf_token:
        os.environ["HF_TOKEN"] = hf_token
        os.environ["HUGGING_FACE_HUB_TOKEN"] = hf_token

    _embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

    # Load knowledge base and split into chunks 
    with open(knowledge_base_path, "r", encoding="utf-8") as f:
        knowledge_data = json.load(f)

    raw_docs: list[Document] = []
    for item in knowledge_data:
        doc = Document(
            page_content=item["content"],
            metadata={
                "id": item["id"],
                "category": item["category"],
                "title": item.get("title", ""),
                "region": item.get("region", "General"),
                "keywords": ", ".join(item.get("keywords", [])),
            },
        )
        raw_docs.append(doc)

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap=50,
        length_function=len,
        separators=["\n\n", "\n", ". ", " ", ""],
    )
    _split_docs = splitter.split_documents(raw_docs)
    logger.info("Knowledge base chunked into %d pieces", len(_split_docs))

    # Drop existing collection to prevent duplicates
    os.makedirs(chroma_db_dir, exist_ok=True)
    collection_name = "cancer_knowledge"

    try:
        old_store = Chroma(
            collection_name=collection_name,
            persist_directory=chroma_db_dir,
            embedding_function=_embeddings,
        )
        old_store.delete_collection()
        logger.info("Dropped existing ChromaDB collection")
    except Exception:
        logger.info("No previous ChromaDB collection found; building fresh index")

    _vectorstore= Chroma.from_documents(
        documents=_split_docs,
        embedding=_embeddings,
        persist_directory=chroma_db_dir,
        collection_name=collection_name,
    )
    logger.info("ChromaDB indexed %d chunks", len(_split_docs))

    # Gemini LLM
    _llm = ChatGoogleGenerativeAI(
        model="gemini-2.5-flash-lite",
        google_api_key=gemini_api_key,
        temperature=0.7,
        max_output_tokens=2048,
    )

    _engine_initialized = True
    logger.info("Chatbot engine ready")

    # Prewarm to avoid slow first request
    try:
        logger.info("Pre-warming Gemini LLM")
        _llm.invoke("Say OK")
        logger.info("Gemini pre-warm complete")
    except Exception:
        logger.warning("Gemini pre-warm failed first request may be slow")


# Knowledge retrieval

def _doc_key(doc: Document) -> str:
    return doc.metadata.get("id") or doc.metadata.get("title") or doc.page_content[:120]


def _extract_query_terms(query: str) -> set:
    words = re.findall(r"\w+", query.lower())
    return {t for t in words if t not in DEFAULT_STOP_WORDS and len(t) > 2}


def _lexical_score(doc: Document, query_terms: set) -> int:
    text = f"{doc.metadata.get('title', '')} {doc.page_content}".lower()
    terms_in_doc = set(re.findall(r"\w+", text))
    return len(query_terms & terms_in_doc)


def _search_knowledge(query: str, top_n: int = 2) -> list[dict]:
    query_terms = _extract_query_terms(query)
    semantic_hits = _vectorstore.similarity_search_with_score(query, k=20)
    combined: dict[str, dict] = {}

    for doc, raw_score in semantic_hits:
        key = _doc_key(doc)
        distance = abs(float(raw_score))
        sem_score = 1.0 / (1.0 + distance)
        combined[key] = {
            "doc"     : doc,
            "semantic": sem_score,
            "lexical" : _lexical_score(doc, query_terms),
        }

    # Add manual keyword matches
    for doc in _split_docs:
        key = _doc_key(doc)
        lex= _lexical_score(doc, query_terms)
        if lex <= 0:
            continue
        if key not in combined:
            combined[key] = {"doc": doc, "semantic": 0.0, "lexical": lex}
        else:
            combined[key]["lexical"] = max(combined[key]["lexical"], lex)

    # Rank by combined semantic and lexical scores
    ranked = sorted(
        combined.values(),
        key=lambda r: r["semantic"] + 0.25 * r["lexical"],
        reverse=True,
    )

    # Filter out low confidence results semantic threshold 0.45 prevents irrelevant chunks
    high_confidence = [r for r in ranked if r["semantic"] >= 0.45 or r["lexical"] >= 2]

    final_results: list[dict] = []
    seen_titles: set[str] = set()

    for row in high_confidence:
        doc= row["doc"]
        title = (doc.metadata.get("title") or "Untitled").strip()
        if title in seen_titles:
            continue
        seen_titles.add(title)
        final_results.append(row)
        if len(final_results) == top_n:
            break

    return final_results


def _retrieve_knowledge(query: str, top_n: int = 2) -> dict:
    results = _search_knowledge(query, top_n=top_n)

    if results:
        contexts: list[str] = []
        sources : list[str] = []
        for row in results:
            doc= row["doc"]
            title = doc.metadata.get("title") or "Untitled"
            contexts.append(f"Source: {title}\n{doc.page_content}")
            sources.append(title)
        knowledge_context = "\n\n".join(contexts)
        return {
            "user_message": query,
            "knowledge_found": True,
            "knowledge_context": knowledge_context,
            "sources": sources,
            "prompt_input": f"User message:\n{query}\n\nKnowledge context:\n{knowledge_context}",
        }

    return {
        "user_message": query,
        "knowledge_found": False,
        "knowledge_context": "",
        "sources": [],
        "prompt_input": query,
    }

# Prompt formulation
def _formulate_prompt(safety_report: dict, knowledge_context: dict | None = None) -> dict:
    if safety_report["safety_flag"] == "crisis":
        return {
            "user_message": safety_report["user_message"],
            "sentiment_label": safety_report["emotion_label"],
            "safety_flag": safety_report["safety_flag"],
            "knowledge_found": False,
            "knowledge_context": "",
            "sources": [],
        }

    knowledge_context = knowledge_context or {
        "knowledge_found": False,
        "knowledge_context": "",
        "sources": [],
    }

    return {
        "user_message": safety_report["user_message"],
        "sentiment_label"  : safety_report["emotion_label"],
        "safety_flag" : safety_report["safety_flag"],
        "knowledge_found"  : knowledge_context["knowledge_found"],
        "knowledge_context": knowledge_context["knowledge_context"],
        "sources": knowledge_context["sources"],
    }

# Gemini generation
def _generate_with_gemini(user_prompt: str, is_crisis: bool = False) -> str:
    try:
        full_prompt = f"\n{SYSTEM_PROMPT}\n\nFollow the system instructions above strictly.\n\n{user_prompt}"
        response = _llm.invoke(full_prompt)
        content  = getattr(response, "content", None)
        if isinstance(content, str) and content.strip():
            return content.strip()
        text = getattr(response, "text", None)
        if isinstance(text, str) and text.strip():
            return text.strip()
        return str(response)
    except Exception as exc:
        error_text = str(exc).lower()
        is_quota = any(kw in error_text for kw in (
            "resourceexhausted", "quota", "429", "exceeded", "rate limit",
        ))
        if is_quota:
            logger.warning("Gemini quota/rate-limit hit: %s", exc)
            if is_crisis:
                return random.choice(CRISIS_FALLBACK_TEMPLATES)
            return (
                "I'm sorry, I'm a bit overwhelmed with requests right now. "
                "Could you try sending your message again in a minute? I'm still here for you."
            )
        raise


def _stream_with_gemini(user_prompt: str, is_crisis: bool = False):
    # Streams response from Gemini token by token
    try:
        full_prompt = f"\n{SYSTEM_PROMPT}\n\nFollow the system instructions above strictly.\n\n{user_prompt}"
        for chunk in _llm.stream(full_prompt):
            text = getattr(chunk, "content", None) or getattr(chunk, "text", None)
            if text:
                yield str(text)
    except Exception as exc:
        error_text = str(exc).lower()
        is_quota = any(kw in error_text for kw in (
            "resourceexhausted", "quota", "429", "exceeded", "rate limit",
        ))
        if is_quota:
            logger.warning("Gemini quota/rate-limit hit during stream: %s", exc)
            if is_crisis:
                yield random.choice(CRISIS_FALLBACK_TEMPLATES)
            else:
                yield (
                    "I'm sorry, I'm a bit overwhelmed with requests right now. "
                    "Could you try sending your message again in a minute? I'm still here for you."
                )
        else:
            raise


def _format_history_for_prompt(history: list[dict]) -> str:
    if not history:
        return "No previous conversation."
    lines = []
    for msg in history[-10:]:
        prefix = "User" if msg["role"] in ("user", "patient") else "Ayu"
        lines.append(f"{prefix}: {msg['content']}")
    return "\n".join(lines)


# User summary
def _generate_user_summary(emotions: list[str], crisis_count: int, total_messages: int) -> str:
    if not emotions:
        return "New user, no conversation history yet."
    counts  = Counter(emotions)
    top = counts.most_common(2)
    top_str = ", ".join(f"{e} ({c}x)" for e, c in top)
    return (
        f"User has sent {total_messages} message(s). "
        f"Recent emotional trends: {top_str}. "
        f"Crisis episodes: {crisis_count}."
    )


_MEMORY_USAGE_INSTRUCTIONS = """
MEMORY RULES — HARD CONSTRAINTS, NO EXCEPTIONS:

1. NEVER mention, quote, paraphrase, or allude to anything in this memory unless
   the user has already brought up that exact topic themselves in THIS conversation.

2. NEVER open with a reference to past sessions. If the user says "hi", "hello",
   or anything casual, respond ONLY to what they said right now. Do not say things
   like "How are you feeling after what you shared last time?" or "Last time you
   mentioned…" — this is forbidden.

3. USE memory silently for:
   - Adjusting your tone (e.g. memory says chronic anxiety → be extra gentle, but
     do NOT say you know they're anxious)
   - Medical accuracy (e.g. knowing their cancer type so you don't give wrong advice)
   - Recognising when a topic the user raises NOW connects to something in memory
     (e.g. user asks about hospital transport → you know their stage, tailor the answer)

4. USE memory openly ONLY when:
   - The user explicitly asks you to remember ("do you remember I told you…")
   - The user themselves brings up the past topic first in this conversation

5. NEVER use memory for: greetings, small talk, emotional openers, unprompted check-ins
   about past events, or any sentence that starts with "I remember" or "Last time".

Violation of these rules breaks the user's trust. Do not violate them.
"""

def _build_memory_block(long_term_summary: str) -> str:
    """Wrap the long-term summary with hard-constraint rules so Gemini
    only surfaces memories when the user explicitly raises the topic."""
    if not long_term_summary or not long_term_summary.strip():
        return ""
    return f"""
BACKGROUND MEMORY — SILENT USE ONLY — DO NOT MENTION UNPROMPTED
{long_term_summary.strip()}
END BACKGROUND MEMORY
{_MEMORY_USAGE_INSTRUCTIONS}"""


# Word limit for the long-term summary stored in Firestore
_LONG_TERM_SUMMARY_WORD_LIMIT = 300

# Priority hierarchy communicated to Gemini when condensing the summary
_LONG_TERM_SUMMARY_PRIORITY = """
Priority — what to KEEP (highest to lowest):
1. Safety-critical facts: suicidal ideation history, crisis episodes, crisis contacts used.
2. Medical facts: cancer type, stage, current treatment, hospital, doctor name, medication.
3. Close relationships: names of spouse/partner, children, parents, best friend, companion.
4. Life circumstances: job status, living situation, financial stress, caregiving role.
5. Emotional patterns: chronic fears, major sources of stress, coping strategies that work.
6. Preferences and habits Ayu should remember: preferred name, communication style preferences.
7. Positive milestones: treatment victories, good news, things the patient is proud of.

What to DROP when over the word limit (lowest priority first):
- One-off mood mentions that have no lasting significance.
- Repetitive small talk that was already summarised.
- Any facts already implied by higher-priority items.
"""


def generate_long_term_summary(existing_summary: str,conversation_history: list[dict],user_summary: str,) -> str:
    # Updates the long-term summary using the latest conversation while keeping it under the word limit
    if not _llm:
        return existing_summary

    history_text = _format_history_for_prompt(conversation_history)
    existing_block = existing_summary.strip() if existing_summary.strip() else "None yet."

    prompt = f"""You are a memory assistant for Ayu, a cancer-support chatbot in Sri Lanka.

Your job: produce an updated long-term memory summary for one patient by merging
the EXISTING SUMMARY with what happened in the CURRENT CONVERSATION.

EXISTING SUMMARY:
{existing_block}

CURRENT CONVERSATION:
{history_text}

CURRENT SESSION STATS:
{user_summary}

{_LONG_TERM_SUMMARY_PRIORITY}

Rules:
- Write in third-person ("The patient...").
- Hard word limit: {_LONG_TERM_SUMMARY_WORD_LIMIT} words. Stay under it.
- Do NOT invent facts that were not mentioned.
- Do NOT include the current date or session IDs.
- Output ONLY the updated summary text, nothing else.
"""

    try:
        response = _llm.invoke(prompt)
        content= getattr(response, "content", None) or getattr(response, "text", None)
        return str(content).strip() if content else existing_summary
    except Exception as exc:
        logger.warning("Could not update long-term summary (%s) — keeping existing one.", exc)
        return existing_summary


# Response handlers
def _handle_crisis_response(
    persona_packet: dict,
    conversation_history: list[dict],
    user_summary : str,
    long_term_summary : str = "",
) -> str:
    """
    The response for a crisis message is assembled as:
        CRISIS_HARDCODED_PREFIX + " " + Gemini continuation
    so the user sees one single, natural-sounding message.
    """
    history_context = _format_history_for_prompt(conversation_history)
    memory_block = _build_memory_block(long_term_summary)

    prompt = f"""CRISIS SITUATION - Someone may be in danger.

CRITICAL INSTRUCTION:
A short message has ALREADY been sent to them: "{CRISIS_HARDCODED_PREFIX}"

Your job is to write ONLY what comes AFTER that opening message.
Do NOT repeat or rephrase "{CRISIS_HARDCODED_PREFIX}" in any way.

Your continuation should:
1. Keep them talking - ask if they're safe right now or if someone is with them
2. Show genuine care without sounding clinical or robotic
3. Gently mention calling 1990 (ambulance) if they're in immediate danger
4. Keep your tone calm, warm, and human - like a caring friend who's genuinely worried
5. Be brief and direct - this is urgent

{memory_block}

Recent conversation:
{history_context}

Session stats: {user_summary}

Detected emotion: {persona_packet['sentiment_label']}

What they just said: {persona_packet['user_message']}

Remember: Just write the continuation. The opening "{CRISIS_HARDCODED_PREFIX}" is already there.
"""

    continuation = _generate_with_gemini(prompt, is_crisis=True).strip()
    return f"{CRISIS_HARDCODED_PREFIX} {continuation}"


def _handle_knowledge_based_response(
    persona_packet: dict,
    conversation_history: list[dict],
    user_summary : str,
    long_term_summary : str = "",
) -> str:
    history_context= _format_history_for_prompt(conversation_history)
    knowledge_context = (
        persona_packet["knowledge_context"]
        if persona_packet["knowledge_found"]
        else "No specific information found in knowledge base."
    )
    memory_block = _build_memory_block(long_term_summary)

    prompt = f"""Someone is asking about cancer resources or info in Sri Lanka.

CRITICAL: Only answer using the knowledge context below. If the answer is not in the context, say "I don't have that specific info, but you can call Apeksha Hospital to ask" or suggest they ask at the hospital directly.

What you know from your knowledge base:
{knowledge_context}

Recent conversation:
{history_context}

User emotion: {persona_packet['sentiment_label']}
Session stats: {user_summary}
{memory_block}

Their question: {persona_packet['user_message']}

Answer naturally based on the provided knowledge. DO NOT make up hospital details, costs, phone numbers, or procedures that are not in the knowledge context above.
"""

    return _generate_with_gemini(prompt, is_crisis=False)


def _handle_general_support(
    persona_packet: dict,
    conversation_history: list[dict],
    user_summary: str,
    long_term_summary : str = "",
) -> str:
    history_context = _format_history_for_prompt(conversation_history)
    memory_block= _build_memory_block(long_term_summary)

    # Only ask a follow up question 40% of the time to avoid it feeling repetitive
    ask_question         = random.random() < 0.4
    question_instruction = (
        "Maybe ask a gentle follow-up question if it feels natural."
        if ask_question
        else "Just listen and validate, no question needed this time."
    )

    prompt = f"""Someone is talking to you about their cancer experience or feelings.

Recent conversation:
{history_context}

Their emotion right now: {persona_packet['sentiment_label']}
Session stats: {user_summary}
{memory_block}

What they said: {persona_packet['user_message']}

Respond like a real caring person. {question_instruction}
Keep it short unless they asked for detailed info.
"""

    return _generate_with_gemini(prompt, is_crisis=False)

def process_user_message(
    user_message : str,
    conversation_history: list[dict],
    user_emotions: list[str],
    crisis_count: int,
    total_messages: int,
    long_term_summary : str = "",
) -> dict:
    # Main chatbot pipeline where it checks safety, gets info if needed and generates a response
    safety_report = analyze_safety(user_message)

    if safety_report["safety_flag"] == "crisis":
        knowledge_context = {
            "user_message": user_message,
            "knowledge_found" : False,
            "knowledge_context": "",
            "sources": [],
            "prompt_input": user_message,
            "retrieval_skipped": True,
            "skip_reason": "crisis_mode",
        }
    elif not has_medical_vocabulary(user_message):
        knowledge_context = {
            "user_message": user_message,
            "knowledge_found": False,
            "knowledge_context": "",
            "sources": [],
            "prompt_input" : user_message,
            "retrieval_skipped": True,
            "skip_reason": "no_medical_vocabulary",
        }
    else:
        retrieved = _retrieve_knowledge(user_message, top_n=2)
        knowledge_context = {
            **retrieved,
            "retrieval_skipped": False,
            "skip_reason"     : None,
        }

    persona_packet = _formulate_prompt(safety_report, knowledge_context)
    user_summary = _generate_user_summary(user_emotions, crisis_count, total_messages)

    if persona_packet["safety_flag"] == "crisis":
        reply = _handle_crisis_response(
            persona_packet, conversation_history, user_summary, long_term_summary
        )
        path_taken = "crisis"
    elif persona_packet["knowledge_found"]:
        reply = _handle_knowledge_based_response(
            persona_packet, conversation_history, user_summary, long_term_summary
        )
        path_taken = "knowledge_based"
    else:
        reply= _handle_general_support(
            persona_packet, conversation_history, user_summary, long_term_summary
        )
        path_taken = "general_support"

    return {
        "response" : reply,
        "sentiment": safety_report["emotion_label"],
        "safety_flag": safety_report["safety_flag"],
        "triggered_by": safety_report["triggered_by"],
        "suicidal_confidence": safety_report["suicidal_confidence"],
        "path_taken" : path_taken,
        "sources": persona_packet.get("sources", []),
    }


#  Builds prompts for different response types
def _build_prompt_for_handler(handler_type: str,persona_packet: dict,conversation_history: list[dict],user_summary: str,
long_term_summary: str = "",
) -> str:
    history_context = _format_history_for_prompt(conversation_history)
    memory_block = _build_memory_block(long_term_summary)

    if handler_type == "crisis":
        return f"""CRISIS SITUATION - Someone may be in danger.

CRITICAL INSTRUCTION:
A short message has ALREADY been sent to them: "{CRISIS_HARDCODED_PREFIX}"

Your job is to write ONLY what comes AFTER that opening message.
Do NOT repeat or rephrase "{CRISIS_HARDCODED_PREFIX}" in any way.

Your continuation should:
1. Keep them talking - ask if they're safe right now or if someone is with them
2. Show genuine care without sounding clinical or robotic
3. Gently mention calling 1990 (ambulance) if they're in immediate danger
4. Keep your tone calm, warm, and human - like a caring friend who's genuinely worried
5. Be brief and direct - this is urgent

{memory_block}

Recent conversation:
{history_context}

Session stats: {user_summary}

Detected emotion: {persona_packet['sentiment_label']}

What they just said: {persona_packet['user_message']}

Remember: Just write the continuation. The opening "{CRISIS_HARDCODED_PREFIX}" is already there.
"""

    if handler_type == "knowledge":
        knowledge_context = (
            persona_packet["knowledge_context"]
            if persona_packet["knowledge_found"]
            else "No specific information found in knowledge base."
        )
        return f"""Someone is asking about cancer resources or info in Sri Lanka.

CRITICAL: Only answer using the knowledge context below. If the answer is not in the context, say "I don't have that specific info, but you can call Apeksha Hospital to ask" or suggest they ask at the hospital directly.

What you know from your knowledge base:
{knowledge_context}

Recent conversation:
{history_context}

User emotion: {persona_packet['sentiment_label']}
Session stats: {user_summary}
{memory_block}

Their question: {persona_packet['user_message']}

Answer naturally based on the provided knowledge. DO NOT make up hospital details, costs, phone numbers, or procedures that are not in the knowledge context above.
"""

    ask_question = random.random() < 0.4
    question_instruction = (
        "Maybe ask a gentle follow-up question if it feels natural."
        if ask_question
        else "Just listen and validate, no question needed this time."
    )
    return f"""Someone is talking to you about their cancer experience or feelings.

Recent conversation:
{history_context}

Their emotion right now: {persona_packet['sentiment_label']}
Session stats: {user_summary}
{memory_block}

What they said: {persona_packet['user_message']}

Respond like a real caring person. {question_instruction}
Keep it short unless they asked for detailed info.
"""


def prepare_streaming_context(
    user_message: str,
    conversation_history: list[dict],
    user_emotions: list[str],
    crisis_count: int,
    total_messages: int,
    long_term_summary: str = "",
) -> dict:
    # Runs safety check, retrieval, and prompt building and returns data needed for streaming without calling Gemini
    safety_report = analyze_safety(user_message)

    if safety_report["safety_flag"] == "crisis":
        knowledge_context = {
            "user_message": user_message,
            "knowledge_found": False,
            "knowledge_context": "",
            "sources": [],
            "prompt_input": user_message,
            "retrieval_skipped": True,
            "skip_reason": "crisis_mode",
        }
    elif not has_medical_vocabulary(user_message):
        knowledge_context = {
            "user_message": user_message,
            "knowledge_found": False,
            "knowledge_context": "",
            "sources": [],
            "prompt_input": user_message,
            "retrieval_skipped": True,
            "skip_reason": "no_medical_vocabulary",
        }
    else:
        retrieved = _retrieve_knowledge(user_message, top_n=2)
        knowledge_context = {**retrieved, "retrieval_skipped": False, "skip_reason": None}

    persona_packet = _formulate_prompt(safety_report, knowledge_context)
    user_summary = _generate_user_summary(user_emotions, crisis_count, total_messages)

    if persona_packet["safety_flag"] == "crisis":
        handler_type = "crisis"
        path_taken = "crisis"
    elif persona_packet["knowledge_found"]:
        handler_type = "knowledge"
        path_taken  = "knowledge_based"
    else:
        handler_type = "general"
        path_taken = "general_support"

    prompt = _build_prompt_for_handler(
        handler_type, persona_packet, conversation_history,
        user_summary, long_term_summary,
    )

    return {
        "prompt" : prompt,
        "handler_type": handler_type,
        "path_taken": path_taken,
        "sentiment": safety_report["emotion_label"],
        "safety_flag": safety_report["safety_flag"],
        "triggered_by": safety_report["triggered_by"],
        "suicidal_confidence": safety_report["suicidal_confidence"],
        "sources": persona_packet.get("sources", []),
        "is_crisis": safety_report["safety_flag"] == "crisis",
    }


def stream_gemini_response(prompt: str, is_crisis: bool = False):
    # Streams Gemini response in small chunks as it generates
    if is_crisis:
        yield CRISIS_HARDCODED_PREFIX + " "
    yield from _stream_with_gemini(prompt, is_crisis=is_crisis)