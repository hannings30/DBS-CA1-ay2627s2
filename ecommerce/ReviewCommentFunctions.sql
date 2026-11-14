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
