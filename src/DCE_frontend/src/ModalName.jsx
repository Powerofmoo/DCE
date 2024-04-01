import React, { useState } from 'react';
import { DCE_authBackend } from "./DCE_authBackend";

const ModalName = ({ isOpen, onClose, onCancel }) => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    const result = await submitEntry({ name, email });
    if (result) {
      onClose(); // Close modal if entry is successful
    } else {
      setErrorMessage('Failed to record entry. Please try again.');
    }
  };

  const submitEntry = async ({ name, email }) => {
    try {
      console.log('Submitting entry:', { name, email });

      await DCE_authBackend.setName(name);

      if (email) {
        await DCE_authBackend.claimEmail("", email);
      }

      return true;
    } catch (error) {
      console.error('Submission failed:', error);
      return false;
    }
  };

  return (
    <div style={styles.overlay}>
      <div style={styles.modal}>
        <button onClick={onCancel} style={styles.closeButton}>X</button>
        <form onSubmit={handleSubmit}>
          <div>
            <label>Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </div>
          <div>
            <label>Email (opt):</label>
            <input
              type="text"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
    
          <button type="submit">Register</button>
        </form>
        {errorMessage && <p style={styles.errorMessage}>{errorMessage}</p>}
      </div>
    </div>
  );
};

const styles = {
  overlay: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modal: {
    background: 'white',
    padding: '20px',
    borderRadius: '10px',
    width: '500px',
    position: 'relative',
  },
  closeButton: {
    position: 'absolute',
    top: '10px',
    right: '10px',
  },
  errorMessage: {
    color: 'red',
  },
};

export default ModalName;
