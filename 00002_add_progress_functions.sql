/*
# Add Progress Tracking Functions

## 1. New Functions
- `get_courses_with_progress`: Returns courses with user progress statistics

## 2. Purpose
- Efficiently calculate user progress across courses
- Provide aggregated statistics for dashboard display
*/

CREATE OR REPLACE FUNCTION get_courses_with_progress(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  language text,
  difficulty text,
  order_index integer,
  created_at timestamptz,
  total_lessons bigint,
  completed_lessons bigint,
  progress_percentage numeric
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    c.id,
    c.title,
    c.description,
    c.language,
    c.difficulty,
    c.order_index,
    c.created_at,
    COUNT(DISTINCT l.id) as total_lessons,
    COUNT(DISTINCT CASE WHEN up.completed = true THEN l.id END) as completed_lessons,
    CASE 
      WHEN COUNT(DISTINCT l.id) > 0 THEN
        ROUND((COUNT(DISTINCT CASE WHEN up.completed = true THEN l.id END)::numeric / COUNT(DISTINCT l.id)::numeric) * 100, 0)
      ELSE 0
    END as progress_percentage
  FROM courses c
  LEFT JOIN lessons l ON l.course_id = c.id
  LEFT JOIN user_progress up ON up.lesson_id = l.id AND up.user_id = p_user_id
  GROUP BY c.id, c.title, c.description, c.language, c.difficulty, c.order_index, c.created_at
  ORDER BY c.order_index;
$$;