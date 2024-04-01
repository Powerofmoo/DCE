import React from 'react';

const ProcessingModal = ({ isOpen}) => {

  if (!isOpen) return null;

  return (
    <div style={mystyles.overlay}>
      <div style={mystyles.modal}>
        <h2>Processing...</h2>
      </div>
    </div>
  );
};

const mystyles = {
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
    padding: '20px',
    background: 'white',
    borderRadius: '5px',
  },
};

export default ProcessingModal;