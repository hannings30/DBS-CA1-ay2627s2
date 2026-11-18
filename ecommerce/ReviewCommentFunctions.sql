-- CA1 database functions for reviews and comments.
-- Add one function at a time, then test each directly in pgAdmin.

-- Create a review only when this member has a completed order containing
-- the selected product. The application must pass the authenticated
-- member ID from req.user, not a member ID supplied by the browser form.
CREATE OR REPLACE FUNCTION public.create_review(
    p_member_id INTEGER,
    p_product_id INTEGER,
    p_rating SMALLINT,
    p_review_text TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_review_id INTEGER;
    v_completed_order_count INTEGER;
BEGIN
    IF p_member_id IS NULL THEN
        RAISE EXCEPTION 'Member is required.';
    END IF;

    IF p_product_id IS NULL THEN
        RAISE EXCEPTION 'Product is required.';
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5.';
    END IF;

    IF p_review_text IS NULL OR BTRIM(p_review_text) = '' THEN
        RAISE EXCEPTION 'Review text cannot be empty.';
    END IF;

    SELECT COUNT(*) INTO v_completed_order_count
    FROM public.sale_order AS so
    JOIN public.sale_order_item AS soi
        ON soi.sale_order_id = so.id
    WHERE so.member_id = p_member_id
      AND so.status = 'COMPLETED'
      AND soi.product_id = p_product_id;

    IF v_completed_order_count = 0 THEN
        RAISE EXCEPTION 'A completed order for this product is required before reviewing it.';
    END IF;

    INSERT INTO public.review (member_id, product_id, rating, review_text)
    VALUES (p_member_id, p_product_id, p_rating, BTRIM(p_review_text))
    RETURNING id INTO v_review_id;

    RETURN v_review_id;
END;
$$;

-- Retrieve a member's reviews with the product name for display.
CREATE OR REPLACE FUNCTION public.get_reviews(
    p_member_id INTEGER
)
RETURNS TABLE (
    review_id INTEGER,
    product_id INTEGER,
    product_name VARCHAR(255),
    rating SMALLINT,
    review_text TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE,
    updated_at TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_member_id IS NULL THEN
        RAISE EXCEPTION 'Member is required.';
    END IF;

    RETURN QUERY
    SELECT r.id,
           r.product_id,
           p.name,
           r.rating,
           r.review_text,
           r.created_at,
           r.updated_at
    FROM public.review AS r
    JOIN public.product AS p
        ON p.id = r.product_id
    WHERE r.member_id = p_member_id
    ORDER BY r.created_at DESC, r.id DESC;
END;
$$;

-- Update a review only when it belongs to the member making the request.
CREATE OR REPLACE FUNCTION public.update_review(
    p_review_id INTEGER,
    p_member_id INTEGER,
    p_rating SMALLINT,
    p_review_text TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_review_count INTEGER;
BEGIN
    IF p_review_id IS NULL THEN
        RAISE EXCEPTION 'Review is required.';
    END IF;

    IF p_member_id IS NULL THEN
        RAISE EXCEPTION 'Member is required.';
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5.';
    END IF;

    IF p_review_text IS NULL OR BTRIM(p_review_text) = '' THEN
        RAISE EXCEPTION 'Review text cannot be empty.';
    END IF;

    SELECT COUNT(*) INTO v_review_count
    FROM public.review
    WHERE id = p_review_id
      AND member_id = p_member_id;

    IF v_review_count = 0 THEN
        RAISE EXCEPTION 'Review not found or you do not have permission to update it.';
    END IF;

    UPDATE public.review
    SET rating = p_rating,
        review_text = BTRIM(p_review_text),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_review_id
      AND member_id = p_member_id;

    RETURN p_review_id;
END;
$$;

-- Delete a review only when it belongs to the member making the request.
CREATE OR REPLACE FUNCTION public.delete_review(
    p_review_id INTEGER,
    p_member_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_review_count INTEGER;
BEGIN
    IF p_review_id IS NULL THEN
        RAISE EXCEPTION 'Review is required.';
    END IF;

    IF p_member_id IS NULL THEN
        RAISE EXCEPTION 'Member is required.';
    END IF;

    SELECT COUNT(*) INTO v_review_count
    FROM public.review
    WHERE id = p_review_id
      AND member_id = p_member_id;

    IF v_review_count = 0 THEN
        RAISE EXCEPTION 'Review not found or you do not have permission to delete it.';
    END IF;

    DELETE FROM public.review
    WHERE id = p_review_id
      AND member_id = p_member_id;

    RETURN p_review_id;
END;
$$;

-- Create a top-level comment or a reply on a review.
CREATE OR REPLACE FUNCTION public.create_comment(
    p_review_id INTEGER,
    p_member_id INTEGER,
    p_parent_comment_id INTEGER,
    p_comment_text TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_review_count INTEGER;
    v_review_author_id INTEGER;
    v_parent_count INTEGER;
    v_parent_author_count INTEGER;
    v_comment_id INTEGER;
BEGIN
    IF p_review_id IS NULL THEN
        RAISE EXCEPTION 'Review is required.';
    END IF;

    IF p_member_id IS NULL THEN
        RAISE EXCEPTION 'Member is required.';
    END IF;

    IF p_comment_text IS NULL OR BTRIM(p_comment_text) = '' THEN
        RAISE EXCEPTION 'Comment text cannot be empty.';
    END IF;

    SELECT COUNT(*) INTO v_review_count
    FROM public.review
    WHERE id = p_review_id;

    IF v_review_count = 0 THEN
        RAISE EXCEPTION 'Review not found.';
    END IF;

    SELECT member_id INTO v_review_author_id
    FROM public.review
    WHERE id = p_review_id;

    IF p_parent_comment_id IS NULL THEN
        IF p_member_id = v_review_author_id THEN
            RAISE EXCEPTION 'The review author cannot add a top-level comment to their own review.';
        END IF;
    ELSE
        SELECT COUNT(*) INTO v_parent_count
        FROM public.comment
        WHERE id = p_parent_comment_id
          AND review_id = p_review_id;

        IF v_parent_count = 0 THEN
            RAISE EXCEPTION 'Parent comment must belong to this review.';
        END IF;

        IF p_member_id = v_review_author_id THEN
            SELECT COUNT(*) INTO v_parent_author_count
            FROM public.comment
            WHERE id = p_parent_comment_id
              AND review_id = p_review_id
              AND member_id <> v_review_author_id;

            IF v_parent_author_count = 0 THEN
                RAISE EXCEPTION 'The review author can reply only to another member''s comment.';
            END IF;
        END IF;
    END IF;

    INSERT INTO public.comment (
        review_id,
        member_id,
        parent_comment_id,
        comment_text
    )
    VALUES (
        p_review_id,
        p_member_id,
        p_parent_comment_id,
        BTRIM(p_comment_text)
    )
    RETURNING id INTO v_comment_id;

    RETURN v_comment_id;
END;
$$;

-- Retrieve a review's comments in creation order, including reply links.
CREATE OR REPLACE FUNCTION public.get_comments(
    p_review_id INTEGER
)
RETURNS TABLE (
    comment_id INTEGER,
    review_id INTEGER,
    member_id INTEGER,
    member_username VARCHAR(50),
    parent_comment_id INTEGER,
    comment_text TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_review_count INTEGER;
BEGIN
    IF p_review_id IS NULL THEN
        RAISE EXCEPTION 'Review is required.';
    END IF;

    SELECT COUNT(*) INTO v_review_count
    FROM public.review
    WHERE id = p_review_id;

    IF v_review_count = 0 THEN
        RAISE EXCEPTION 'Review not found.';
    END IF;

    RETURN QUERY
    SELECT c.id,
           c.review_id,
           c.member_id,
           m.username,
           c.parent_comment_id,
           c.comment_text,
           c.created_at
    FROM public.comment AS c
    JOIN public.member AS m
        ON m.id = c.member_id
    WHERE c.review_id = p_review_id
    ORDER BY c.created_at, c.id;
END;
$$;
