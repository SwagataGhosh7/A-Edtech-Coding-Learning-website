/*
# Create Initial Schema for Coding Kira

## 1. New Tables

### profiles
- `id` (uuid, primary key, references auth.users)
- `username` (text, unique, not null)
- `email` (text, unique)
- `role` (user_role enum: 'user', 'admin')
- `avatar_url` (text)
- `created_at` (timestamptz)

### courses
- `id` (uuid, primary key)
- `title` (text, not null)
- `description` (text)
- `language` (text, not null) - Programming language
- `difficulty` (text) - beginner, intermediate, advanced
- `order_index` (integer)
- `created_at` (timestamptz)

### lessons
- `id` (uuid, primary key)
- `course_id` (uuid, references courses)
- `title` (text, not null)
- `content` (text) - Tutorial content
- `code_template` (text) - Starting code
- `order_index` (integer)
- `created_at` (timestamptz)

### exercises
- `id` (uuid, primary key)
- `lesson_id` (uuid, references lessons)
- `title` (text, not null)
- `description` (text)
- `difficulty` (text)
- `starter_code` (text)
- `solution` (text)
- `test_cases` (jsonb) - Test cases for validation
- `order_index` (integer)
- `created_at` (timestamptz)

### user_progress
- `id` (uuid, primary key)
- `user_id` (uuid, references profiles)
- `lesson_id` (uuid, references lessons)
- `completed` (boolean)
- `completed_at` (timestamptz)
- `created_at` (timestamptz)

### exercise_submissions
- `id` (uuid, primary key)
- `user_id` (uuid, references profiles)
- `exercise_id` (uuid, references exercises)
- `code` (text)
- `passed` (boolean)
- `submitted_at` (timestamptz)

## 2. Security
- Enable RLS on all tables
- Public read access for courses, lessons, exercises
- Users can read/write their own progress and submissions
- Admins have full access to all tables
- First registered user becomes admin via trigger

## 3. Notes
- Using username/password authentication with @miaoda.com suffix
- Progress tracking for personalized learning experience
- Exercise system with test cases for validation
*/

-- Create user role enum
CREATE TYPE user_role AS ENUM ('user', 'admin');

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  email text UNIQUE,
  role user_role DEFAULT 'user'::user_role NOT NULL,
  avatar_url text,
  created_at timestamptz DEFAULT now()
);

-- Create courses table
CREATE TABLE IF NOT EXISTS courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  language text NOT NULL,
  difficulty text DEFAULT 'beginner',
  order_index integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create lessons table
CREATE TABLE IF NOT EXISTS lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid REFERENCES courses(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text,
  code_template text,
  order_index integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create exercises table
CREATE TABLE IF NOT EXISTS exercises (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid REFERENCES lessons(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  difficulty text DEFAULT 'easy',
  starter_code text,
  solution text,
  test_cases jsonb DEFAULT '[]'::jsonb,
  order_index integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create user_progress table
CREATE TABLE IF NOT EXISTS user_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  lesson_id uuid REFERENCES lessons(id) ON DELETE CASCADE,
  completed boolean DEFAULT false,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, lesson_id)
);

-- Create exercise_submissions table
CREATE TABLE IF NOT EXISTS exercise_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  exercise_id uuid REFERENCES exercises(id) ON DELETE CASCADE,
  code text,
  passed boolean DEFAULT false,
  submitted_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_submissions ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(uid uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = uid AND p.role = 'admin'::user_role
  );
$$;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins have full access to profiles" ON profiles
  FOR ALL USING (is_admin(auth.uid()));

-- Courses policies (public read, admin write)
CREATE POLICY "Courses are viewable by everyone" ON courses
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage courses" ON courses
  FOR ALL USING (is_admin(auth.uid()));

-- Lessons policies (public read, admin write)
CREATE POLICY "Lessons are viewable by everyone" ON lessons
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage lessons" ON lessons
  FOR ALL USING (is_admin(auth.uid()));

-- Exercises policies (public read, admin write)
CREATE POLICY "Exercises are viewable by everyone" ON exercises
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage exercises" ON exercises
  FOR ALL USING (is_admin(auth.uid()));

-- User progress policies
CREATE POLICY "Users can view own progress" ON user_progress
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own progress" ON user_progress
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own progress" ON user_progress
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all progress" ON user_progress
  FOR SELECT USING (is_admin(auth.uid()));

-- Exercise submissions policies
CREATE POLICY "Users can view own submissions" ON exercise_submissions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own submissions" ON exercise_submissions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all submissions" ON exercise_submissions
  FOR SELECT USING (is_admin(auth.uid()));

-- Trigger to create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  user_count int;
  extracted_username text;
BEGIN
  IF OLD IS DISTINCT FROM NULL AND OLD.confirmed_at IS NULL AND NEW.confirmed_at IS NOT NULL THEN
    SELECT COUNT(*) INTO user_count FROM profiles;
    
    -- Extract username from email (remove @miaoda.com)
    extracted_username := REPLACE(NEW.email, '@miaoda.com', '');
    
    INSERT INTO profiles (id, username, email, role)
    VALUES (
      NEW.id,
      extracted_username,
      NEW.email,
      CASE WHEN user_count = 0 THEN 'admin'::user_role ELSE 'user'::user_role END
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Insert sample courses and lessons
INSERT INTO courses (title, description, language, difficulty, order_index) VALUES
('JavaScript Fundamentals', 'Learn the basics of JavaScript programming', 'JavaScript', 'beginner', 1),
('Python Basics', 'Introduction to Python programming', 'Python', 'beginner', 2),
('Web Development with HTML & CSS', 'Build beautiful websites', 'HTML/CSS', 'beginner', 3);

-- Get course IDs for lessons
DO $$
DECLARE
  js_course_id uuid;
  py_course_id uuid;
  web_course_id uuid;
BEGIN
  SELECT id INTO js_course_id FROM courses WHERE language = 'JavaScript' LIMIT 1;
  SELECT id INTO py_course_id FROM courses WHERE language = 'Python' LIMIT 1;
  SELECT id INTO web_course_id FROM courses WHERE language = 'HTML/CSS' LIMIT 1;

  -- JavaScript lessons
  INSERT INTO lessons (course_id, title, content, code_template, order_index) VALUES
  (js_course_id, 'Variables and Data Types', 
   'Learn about variables, strings, numbers, and booleans in JavaScript.',
   '// Declare a variable\nlet message = "Hello, World!";\nconsole.log(message);',
   1),
  (js_course_id, 'Functions', 
   'Understand how to create and use functions in JavaScript.',
   'function greet(name) {\n  return "Hello, " + name;\n}\n\nconsole.log(greet("Kira"));',
   2),
  (js_course_id, 'Arrays and Loops', 
   'Work with arrays and iterate using loops.',
   'const numbers = [1, 2, 3, 4, 5];\nfor (let i = 0; i < numbers.length; i++) {\n  console.log(numbers[i]);\n}',
   3);

  -- Python lessons
  INSERT INTO lessons (course_id, title, content, code_template, order_index) VALUES
  (py_course_id, 'Python Variables', 
   'Learn about variables and data types in Python.',
   '# Declare a variable\nmessage = "Hello, Python!"\nprint(message)',
   1),
  (py_course_id, 'Python Functions', 
   'Create and use functions in Python.',
   'def greet(name):\n    return f"Hello, {name}"\n\nprint(greet("Kira"))',
   2);

  -- Web Development lessons
  INSERT INTO lessons (course_id, title, content, code_template, order_index) VALUES
  (web_course_id, 'HTML Basics', 
   'Learn the structure of HTML documents.',
   '<!DOCTYPE html>\n<html>\n<head>\n  <title>My Page</title>\n</head>\n<body>\n  <h1>Hello, World!</h1>\n</body>\n</html>',
   1);
END $$;