import functools

MODEL, DIM = "BAAI/bge-base-en-v1.5", 768
MAX_TOKENS = 512
QUERY_PREFIX = "Represent this sentence for searching relevant passages: "  # bge asymmetric retrieval


# Cached fastembed model (~210 MB, downloaded once to the fastembed cache)
@functools.cache
def model():
    from fastembed import TextEmbedding
    return TextEmbedding(MODEL)


# Token count as the model sees it (to check chunks fit MAX_TOKENS)
def tokens(text):
    return len(model().model.tokenizer.encode(text).ids)


# Document vectors (L2-normalized, so cosine)
def docs(texts):
    return [v.tolist() for v in model().embed(texts, batch_size=16)]


# Query vector
def query(q):
    return next(iter(model().embed([QUERY_PREFIX + q]))).tolist()


# pgvector text literal
def lit(v):
    return "[" + ",".join(f"{x:.6f}" for x in v) + "]"
