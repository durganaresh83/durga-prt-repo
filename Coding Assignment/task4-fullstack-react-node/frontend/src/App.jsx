import { useEffect, useState } from 'react';

function App() {
  const [message, setMessage] = useState('Loading...');

  useEffect(() => {
    fetch('/api/hello')
      .then((r) => r.json())
      .then((data) => setMessage(data.message))
      .catch(() => setMessage('Could not reach backend'));
  }, []);

  return (
    <div style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <h1>React + Node on EKS</h1>
      <p>Backend says: {message}</p>
    </div>
  );
}

export default App;
