import React, { useState, useEffect } from 'react';

import { authActor, DCE_authBackend } from "./DCE_authBackend";

import { AuthClient } from "@dfinity/auth-client";
import { HttpAgent } from "@dfinity/agent";

import ProcessingModal from './Modal';
import ModalName from './ModalName'; // Import the modal component
import ModalGrant from './ModalGrant'; // Import the modal component
import ModalTransfer from './ModalTransfer'; // Import the modal component
import { isFunctionExpression } from '@babel/types';


function App() {

  const [isLoggedIn, setIsLoggedIn] = useState(false);

  // modal dialogs
  const [isNameOpen, setIsNameOpen] = useState(false);
  const [isGrantOpen, setIsGrantOpen] = useState(false);
  const [isTransferOpen, setIsTransferOpen] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);

  // account info
  const [orange, setOrange] = useState("..");
  const [green, setGreen] = useState("..");
  const [userName, setUserName] = useState("..");

  const [myID, setMyID] = useState(null);


  async function loginScript (event)
  {
    event.preventDefault();

      let authClient = await AuthClient.create();
      // start the login process and wait for it to finish
      await new Promise((resolve) => {
          authClient.login({
              identityProvider:
                  process.env.DFX_NETWORK === "ic"
                      ? "https://identity.ic0.app"
                      : `http://rdmx6-jaaaa-aaaaa-aaadq-cai.localhost:4943`,
              onSuccess: resolve,
          });
      });
      setIsProcessing(true);
      const identity = authClient.getIdentity();
      const agent = new HttpAgent({ identity });
          await authActor(process.env.CANISTER_ID_DCE_BACKEND, {
          agent,
      });

      // get id, balance  and name
      var logon = await DCE_authBackend.logon();

      setIsLoggedIn(true);
      setMyID(logon.id );
      setOrange(logon.orange.toString());
      setGreen(logon.green.toString());
      setUserName(logon.name);

      setIsProcessing(false);

      // if no name, ask for name
      if (logon.name == "") {
        openName();
      }
      
      return false;


    };

    async function getBalance  () {
      console.log(myID);
      var balance = await DCE_authBackend.getBalance(myID);
      setOrange(balance.orange.toString());
      setGreen(balance.green.toString());
    }
  
    function refresh () {
      
      setIsProcessing(true);
      refreshTransfers();
      getBalance();
  
      return false;
    }
  
  
    // Function to open the modal
    const openName = () => {
      setIsNameOpen(true);
    }
    
    // Function to close the modal
    const closeName = async () => {
      setIsNameOpen(false);
      var name = await DCE_authBackend.getName();
      setUserName(name);
    }
  
    // Function to close the modal
    const cancelName = () => {
      setIsNameOpen(false);
    }
  
    // Function to open the modal
    const openGrant = () => {
      setIsGrantOpen(true);
    }
    
    // Function to close the modal
    const closeGrant = () => {
      setIsGrantOpen(false);
      refresh();
    }
  
     // Function to close the modal
     const cancelGrant = () => {
      setIsGrantOpen(false);
    }
  
    // Function to open the modal
    const openTransfer = () => {
      setIsTransferOpen(true);
    }
    
    // Function to close the modal
    const closeTransfer = () => {
      setIsTransferOpen(false);
      refresh();
    }
    
    // Function to close the modal
    const cancelTransfer = () => {
      setIsTransferOpen(false);
    }
  
  // Assuming you have a function to call the getOpenTransfers method
  function refreshTransfers () {
      DCE_authBackend.showTransfers().then(transfers => {
      // Create table
      let table = document.createElement('table');
      table.className = 'table-community'; 
  
      // Create table header
      let thead = document.createElement('thead');
      let headerRow = document.createElement('tr');
      ['From', 'To', 'Description', 'Amount'].forEach(headerText => {
          let th = document.createElement('th');
          th.appendChild(document.createTextNode(headerText));
          headerRow.appendChild(th);
      });
      thead.appendChild(headerRow);
      table.appendChild(thead);
  
      // Create table body
      let tbody = document.createElement('tbody');
      transfers.forEach(transfer => {
          let row = document.createElement('tr');
          var td;

          // from and to
          td = document.createElement('td');
          td.innerHTML = transfer.from_name != "" ? transfer.from_name : transfer.from;
          row.appendChild(td);
          
          td = document.createElement('td');
          td.innerHTML = transfer.to_name != "" ? transfer.to_name : transfer.to;
          row.appendChild(td);
  
          // reason
          td = document.createElement('td');
          td.innerHTML = transfer.reason;
          row.appendChild(td);

          // add price
          let tdPrice = document.createElement('td');
          var text = "<table cellspacing=5><tr>";
          if (transfer.orange) {
            text += "<td>" + transfer.orange + '</td><td><img src="/orange button x 42.jpg"></td>'; 
          }
          if (transfer.green) {
            if (transfer.orange) text += "<td>+</td>";
            text += "<td>" + transfer.green + '</td><td><img src="/green button x 42.jpg"></td>'; 
  
          }
          text += "</tr></table>";
          tdPrice.innerHTML = text;
          row.appendChild(tdPrice);
  
          // row ready
          tbody.appendChild(row);
      });
      table.appendChild(tbody);
  
      let divElement = document.getElementById('transfers');
      divElement.innerHTML = "";
      divElement.appendChild (table);
  
      setIsProcessing(false);
      
    }).catch(error => {
      console.error('Error retrieving Transfers:', error);
    });
  };

  return (
  <main>
    <img src="logo2.svg" alt="DFINITY logo" />
    <br />
    <br />
    {!isLoggedIn && (
      <div>
        <button id="login" onClick={loginScript} class="button-community">Login to DCE</button>
      </div>
    )}
    {isLoggedIn && (

      <table width="100%" >
        <tr><td></td><td colspan="4">{userName}</td></tr>
        <tr><td></td><td colspan="4"><font size="1">{myID}</font></td></tr>
        <tr><td width="100%"></td>
          <td>{orange}</td><td><img src="/orange button x 42.jpg"/></td>
          <td>{green}</td><td><img src="/green button x 42.jpg"/></td>
        </tr>
      </table>
    )}

    <br />
    {isLoggedIn && (

      <div>
        <button onClick={refresh} class="button-community">Refresh</button>
        <button onClick={openGrant} class="button-community">Grant</button>
        <button onClick={openTransfer} class="button-community">Transfer</button>
        <div id="transfers"></div>
      </div>

    )}

    <ProcessingModal isOpen={isProcessing}/>
    <ModalName isOpen={isNameOpen} onClose={closeName} onCancel={cancelName}/>
    <ModalGrant isOpen={isGrantOpen} onClose={closeGrant} onCancel={cancelGrant}/>
    <ModalTransfer isOpen={isTransferOpen} onClose={closeTransfer}  onCancel={cancelTransfer}/>

  </main>  );
}

export default App;
