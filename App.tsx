import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from '@/hooks/useAuth';
import RequireAuth from '@/components/auth/RequireAuth';
import Header from '@/components/common/Header';
import { Toaster } from '@/components/ui/toaster';
import routes from './routes';

function App() {
  return (
    <Router>
      <AuthProvider>
        <Toaster />
        <RequireAuth whiteList={['/login', '/', '/courses', '/course/*']}>
          <div className="flex flex-col min-h-screen">
            <Header />
            <main className="flex-grow">
              <Routes>
                {routes.map((route, index) => (
                  <Route
                    key={index}
                    path={route.path}
                    element={route.element}
                  />
                ))}
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </main>
          </div>
        </RequireAuth>
      </AuthProvider>
    </Router>
  );
}

export default App;
