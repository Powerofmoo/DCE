import React, { useState } from 'react';
import { DCE_authBackend } from "./DCE_authBackend";

const ModalTransfer = ({ isOpen, onClose, onCancel }) => {
  const [id, setId] = useState('');
  const [orange, setOrange] = useState('');
  const [green, setGreen] = useState('');
  const [text, setText] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    const result = await submitEntry({ id, orange, green, text });
    if (result) {
      onClose(); // Close modal if entry is successful
    } else {
      setErrorMessage('Failed to record entry. Please try again.');
    }
  };

  const submitEntry = async ({  id, orange, green, text }) => {
    try {
      console.log('Submitting entry:', { id, orange, green, text });
      // Simulate a network request
      var ret = await DCE_authBackend.transfer(id, BigInt(orange), BigInt(green), text);
      // Assume the request succeeds; return true for success or false for failure
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
            <label>Principal ID</label>
            <input
              type="text"
              value={id}
              onChange={(e) => setId(e.target.value)}
              required
            />
          </div>
          <div>
            <label>Orange Coins:</label>
            <input
              type="number"
              value={orange}
              onChange={(e) => setOrange(e.target.value)}
              required
            />
          </div>
          <div>
            <label>Green Coins:</label>
            <input
              type="number"
              value={green}
              onChange={(e) => setGreen(e.target.value)}
              required
            />
          </div>
          <div>
            <label>Description:</label>
            <input
              type="text"
              value={text}
              onChange={(e) => setText(e.target.value)}
              required
            />
          </div>

          <button type="submit">Transfer Coins</button>
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

export default ModalTransfer;
