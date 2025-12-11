import Home from './pages/Home';
import Login from './pages/Login';
import Courses from './pages/Courses';
import CourseDetail from './pages/CourseDetail';
import LessonPage from './pages/Lesson';
import Dashboard from './pages/Dashboard';
import Profile from './pages/Profile';
import Admin from './pages/Admin';
import type { ReactNode } from 'react';

interface RouteConfig {
  name: string;
  path: string;
  element: ReactNode;
  visible?: boolean;
}

const routes: RouteConfig[] = [
  {
    name: 'Home',
    path: '/',
    element: <Home />
  },
  {
    name: 'Login',
    path: '/login',
    element: <Login />,
    visible: false
  },
  {
    name: 'Courses',
    path: '/courses',
    element: <Courses />
  },
  {
    name: 'Course Detail',
    path: '/course/:courseId',
    element: <CourseDetail />,
    visible: false
  },
  {
    name: 'Lesson',
    path: '/lesson/:lessonId',
    element: <LessonPage />,
    visible: false
  },
  {
    name: 'Dashboard',
    path: '/dashboard',
    element: <Dashboard />,
    visible: false
  },
  {
    name: 'Profile',
    path: '/profile',
    element: <Profile />,
    visible: false
  },
  {
    name: 'Admin',
    path: '/admin',
    element: <Admin />,
    visible: false
  }
];

export default routes;