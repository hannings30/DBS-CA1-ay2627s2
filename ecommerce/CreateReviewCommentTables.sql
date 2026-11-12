-- CA1 Review and Comment tables
-- Run this after the starter ecommerce database has been restored.


CREATE TABLE IF NOT EXISTS public.review (
    id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    rating SMALLINT NOT NULL,
    review_text TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_member
        FOREIGN KEY (member_id) REFERENCES public.member(id) ON DELETE CASCADE,
    CONSTRAINT fk_review_product
        FOREIGN KEY (product_id) REFERENCES public.product(id) ON DELETE CASCADE,
    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_review_text_not_blank
        CHECK (BTRIM(review_text) <> '')

);

CREATE TABLE IF NOT EXISTS public.comment (
    id SERIAL PRIMARY KEY,
    review_id INTEGER NOT NULL,
    member_id INTEGER NOT NULL,
    parent_comment_id INTEGER,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comment_review
        FOREIGN KEY (review_id) REFERENCES public.review(id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_member
        FOREIGN KEY (member_id) REFERENCES public.member(id) ON DELETE CASCADE,
    CONSTRAINT chk_comment_text_not_blank
        CHECK (BTRIM(comment_text) <> ''),

    -- A reply must refer to a parent comment in the same review.
    -- A comment with replies cannot be deleted until those replies are removed.
    CONSTRAINT uq_comment_id_and_review UNIQUE (id, review_id),
    CONSTRAINT fk_comment_parent_same_review
        FOREIGN KEY (parent_comment_id, review_id)
        REFERENCES public.comment(id, review_id) ON DELETE RESTRICT
);

-- Indexes support common lookups by product, member, review, and parent.
CREATE INDEX IF NOT EXISTS idx_review_product_id ON public.review(product_id);
CREATE INDEX IF NOT EXISTS idx_review_member_id ON public.review(member_id);
CREATE INDEX IF NOT EXISTS idx_comment_review_id ON public.comment(review_id);
CREATE INDEX IF NOT EXISTS idx_comment_parent_comment_id
    ON public.comment(parent_comment_id);
