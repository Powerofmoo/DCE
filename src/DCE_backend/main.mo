import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";

actor {

    // managers
    var DCEmanager: ?Principal = null;
    var managers : [Principal] = [];

    let startAmountOrange = 20;
    let startAmountGreen = 20;

    type LogonInfo = {
        id: Text;
        name: Text;
        orange: Nat;
        green: Nat;
    };

    // account
    type Account = {
        orange: Nat;
        green: Nat;
    };
    var accounts = TrieMap.TrieMap<Principal, Account>(Principal.equal, Principal.hash);

    // name tabel
    var nameTable = TrieMap.TrieMap<Principal, Text>(Principal.equal, Principal.hash);

    // ledger
    type Transfer = {
        authorization: Principal;
        from: Principal;
        to: Principal;
        orange: Nat;
        green: Nat;
        reason: Text;
        dateTime: Text; 
    };
    var transfers: Buffer.Buffer<Transfer> = Buffer.Buffer<Transfer>(10);
    type TransferInfo = {
        authorization: Principal;
        authorization_name: Text;
        from: Principal;
        from_name: Text;
        to: Principal;
        to_name: Text;
        orange: Nat;
        green: Nat;
        reason: Text;
        dateTime: Text; 
    };

    // referals
    type ReferStatus = {#Open; #Confirmed; #Blocked;};
    type Referal = {
        id: Principal;
        status: ReferStatus;
    };
    var emailReferals = TrieMap.TrieMap<Text, Referal>(Text.equal, Text.hash);
    var telegramReferals = TrieMap.TrieMap<Text, Referal>(Text.equal, Text.hash);

    // temporary accounts
    var emailAccounts = TrieMap.TrieMap<Text, Account>(Text.equal, Text.hash);
    var telegramAccounts = TrieMap.TrieMap<Text, Account>(Text.equal, Text.hash);


///////////////////////////
//
// private Functions
//
///////////////////////////


    private func _create_account(principal: Principal) : () {
        if (null == accounts.get(principal)) {
            let account_new : Account = {
                orange = startAmountOrange;
                green =  startAmountGreen;
            };
            accounts.put(principal, account_new);
        }
    };

    private func _addTransfer(auth: Principal, from : Principal, to: Principal, orange: Nat, green: Nat, reason: Text ) {
        let newTransfer = {
            authorization = auth;
            from = from;
            to = to;
            orange = orange;
            green = green;
            reason = reason;
            dateTime = "(now)";
        };
        transfers.add(newTransfer);
    };

    private func _transfer (auth: Principal, from: Principal, to: Principal, orange: Nat, green: Nat, reason: Text) :  (Bool) {

        // NOTE: this function is not concurret proof - hackathon modus
        if (from == to) return false;

         _create_account(from);  // Ensure account exists
         _create_account(to);  // Ensure account exists

        let fromValues = switch (accounts.get(from)) {
            case (null) { return false; };
            case (?values) { values };
        };

        if (fromValues.orange < orange or fromValues.green < green) {
            return false;
        };

        let toValues = switch (accounts.get(to)) {
            case (null) { {orange=0; green=0}; };
            case (?values) { values };
        };

        accounts.put(from, {orange=fromValues.orange - orange; green=fromValues.green - green});
        accounts.put(to, {orange=toValues.orange + orange; green=toValues.green + green});

        // write in transfers
        _addTransfer(auth, from, to , orange, green, reason);

        return true;
    };

    private func _mint(auth: Principal, to: Principal, orange: Nat, green: Nat, reason: Text) :  (Bool) {

         _create_account(to);  // Ensure account exists

        let toValues = switch (accounts.get(to)) {
            case (null) { {orange=0; green=0}; };
            case (?values) { values };
        };

        accounts.put(to, {orange=toValues.orange + orange; green=toValues.green + green});

        // write in transfers
        _addTransfer(auth, auth, to , orange, green, reason);

        return true;
    }; 

    private func _isManager(id: Principal, extended: Bool) : (Bool)
    {
        // check for superuser
        switch (DCEmanager) {
            case (null)
                return false;
            case (?manager)
                if(manager == id) return true;
        };

        if (not extended) return false;

        // check other managers
        let exists = Array.find(managers, func (p: Principal) : Bool {
            return Principal.equal(p, id);
        });
        switch (exists) {
            case null { return false; };
            case _ { return true; };
        };
 
    };
    

///////////////////////////
//
// Management Functions
//
///////////////////////////

  public shared (msg) func addManager(newManagerText: Text) : async (Bool) {
    let newManager = Principal.fromText(newManagerText);

    if ( not _isManager(msg.caller, false) ) return false;

    let exists = Array.find(managers, func (p: Principal) : Bool {
      return Principal.equal(p, newManager);
    });
    switch (exists) {
      case null {
        managers := Array.append<Principal>(managers, [newManager]);
      };
      case _ {};
    };
    return true;
  };

  public shared (msg) func listManagers() : async [Principal] {
    if ( not _isManager(msg.caller, false) ) return [];
    return managers;
  };

///////////////////////////
//
// Basic Account Funcs
//
///////////////////////////

    public shared (msg) func getBalance(idText: Text) : async Account {
        var id = msg.caller;
        if (idText != "") id := Principal.fromText(idText);

        if ( msg.caller != id and not _isManager(msg.caller, true) ) return {orange=0; green=0;} : Account;
 
         _create_account(id);  // Ensure account exists
        let optAccount = accounts.get(id);
        let account = switch (optAccount) {
            case (null) { {orange=0; green=0;} : Account};
            case (?acc) {acc};
        };
        return account;
    };

    public shared (msg) func transfer(toText: Text, orange: Nat, green: Nat, reason: Text) : async (Bool) {
        let to = Principal.fromText(toText);
        return _transfer(msg.caller, msg.caller, to, orange, green, reason);
    }; 

    public shared (msg) func transaction(fromText:Text, toText: Text, orange: Nat, green: Nat, reason: Text) : async (Bool) {
        let from = Principal.fromText(fromText);
        let to = Principal.fromText(toText);
        if (not _isManager(msg.caller, true)) return false;

        return _transfer(msg.caller, from, to, orange, green, reason);
    }; 

///////////////////////////
//
// Buys and Grants
//
///////////////////////////

    public shared (msg) func buy(toText: Text, orange: Nat, reason: Text) : async  (Bool) {
        let auth = msg.caller;
        let to = Principal.fromText(toText);

        if ( not _isManager(msg.caller, true) ) return false;
        
        return _mint (auth, to, orange, 0, reason);

    }; 

    public shared (msg) func grant(toText: Text, green: Nat, reason: Text) : async  (Bool) {
        let auth = msg.caller;
        let to = Principal.fromText(toText);

        if (green > 10) return false;
        
        return _mint (auth, to, 0, green, reason);

    }; 

    public shared (msg) func grantTelegram(to: Text, green: Nat, reason: Text) : async (Bool) {
        let auth = msg.caller;

        if (green > 10) return false;
        
        // check if is already linked to account
        switch (telegramReferals.get(to)) {
            case (null) { 
                // otherwise fall through
             };
            case (?value) { 
                if (value.status == #Confirmed)
                    return _mint (auth, value.id, 0, green, reason);
                if (value.status == #Blocked)
                    return false;
                // otherwise fall through
            }
        };

        // otherwise, get/create from temporary subAccount
        let account = switch (telegramAccounts.get(to)) {
            case (null) { {orange=0; green=0;} };
            case (?value) { value };
        };
        telegramAccounts.put(to, { orange = account.orange; green = account.green + green;});

        return true;
    }; 

    public shared (msg) func grantEmail(to: Text, green: Nat, reason: Text) : async (Bool) {
        let auth = msg.caller;
        
        if (green > 10) return false;
        
        // check if is already linked to account
        switch (emailReferals.get(to)) {
            case (null) { 
                // otherwise fall through
             };
            case (?value) { 
                if (value.status == #Confirmed)
                    return _mint (auth, value.id, 0, green, reason);
                if (value.status == #Blocked)
                    return false;
                // otherwise fall through
            }
        };

        // otherwise, get/create from temporary subAccount
        let account = switch (emailAccounts.get(to)) {
            case (null) { {orange=0; green=0}; };
            case (?value) { value };
        };
        emailAccounts.put(to, { orange = account.orange; green = account.green + green;});

        return true;
    }; 

///////////////////////////
//
// Identity matching
//
///////////////////////////

    public shared (msg) func setName(name: Text) : async (Bool) {
        nameTable.put(msg.caller, name);
        return true;
    };

    public shared (msg) func getName() : async (Text) {
        return switch ( nameTable.get(msg.caller) ) {
            case (null) { "" };
            case (?name) { name }
        };
    };


    public shared (msg) func claimTelegram(idText: Text, referal: Text) : async (Bool) {
        var id = msg.caller;
        if (idText != "") id := Principal.fromText(idText);
        let auth = msg.caller;

        if ( msg.caller != id and not _isManager(msg.caller, true) ) return false;

        // check if is already linked to account
        switch (telegramReferals.get(referal)) {
            case (null) { 
                // otherwise fall through
             };
            case (?value) { 
                if (value.status == #Confirmed)
                    return true;
                if (value.status == #Blocked)
                    return false;
                // otherwise fall through
            }
        };
        
        // otherwise, link and transfer coins (if any)
        telegramReferals.put(referal, {id = id; status = #Confirmed;});
        switch (telegramAccounts.get(referal)) {
            case (null) { /* */ };
            case (?value) { 
                var dum = _mint (auth, id, 0, value.green, "(from Telegram)" );
                telegramAccounts.delete(referal);
             };
        };

        return true;
    };

    public shared (msg) func claimEmail(idText: Text, referal: Text) : async (Bool) {
        var id = msg.caller;
        if (idText != "") id := Principal.fromText(idText);
        let auth = msg.caller;

        if ( msg.caller != id and not _isManager(msg.caller, true) ) return false;

        // check if is already linked to account
        switch (emailReferals.get(referal)) {
            case (null) { 
                // otherwise fall through
             };
            case (?value) { 
                if (value.status == #Confirmed)
                    return true;
                if (value.status == #Blocked)
                    return false;
                // otherwise fall through
            }
        };
        
        // otherwise, link and transfer coins (if any)
        emailReferals.put(referal, {id = id; status = #Confirmed;});
        switch (emailAccounts.get(referal)) {
            case (null) { /* */ };
            case (?value) { 
                var dum = _mint (auth, id, 0, value.green, "(from email " # referal # ")" );
                emailAccounts.delete(referal);
             };
        };    

        return true;
    };


///////////////////////////
//
// Misc
//
///////////////////////////

    private func _lookupName(id: Principal) : Text {
        var found = nameTable.get(id);
        return switch (found) {
            case (null) {""};
            case (?found) {found}
        };
    };

    public shared (msg) func showTransfers () : async ( [TransferInfo] ) {
        let id = msg.caller;

        var outputBuf: Buffer.Buffer<TransferInfo> = Buffer.Buffer<TransferInfo>(10);
        Buffer.iterate<Transfer>(transfers, func (elem) {
            if (elem.from == id or elem.to == id) {
                let transferInfo : TransferInfo = {
                    authorization       = elem.authorization;
                    authorization_name  = _lookupName(elem.authorization);
                    from                = elem.from;
                    from_name           = _lookupName(elem.from);
                    to                  = elem.to;
                    to_name             = _lookupName(elem.to);
                    orange              = elem.orange;
                    green               = elem.green;
                    reason              = elem.reason;
                    dateTime            = elem.dateTime;      
                };
                outputBuf.add(transferInfo);
            };
        });

        return Buffer.toArray<TransferInfo>(outputBuf); // Convert the buffer to an array
    };

///////////////////////////
//
// Debug
//
///////////////////////////

    public func dumpTelegram(id: Text) : async ?Referal {
        return telegramReferals.get(id);
    };

    public func dumpTelegramAccount(id:Text) : async ?Account {
            return telegramAccounts.get(id);
    }; 

    public func dumpEmail(id: Text) : async ?Referal {
        return emailReferals.get(id);
    };

    public func dumpEmailAccount(id:Text) : async ?Account {
            return emailAccounts.get(id);
    }; 

    public shared (msg) func userInfo() : async Text {
        switch(DCEmanager) {
            case (null) {
                return "not set";
            };
            case (?manager) {
                if (manager == msg.caller) return "manager";
            };
        };
        return "user";
    };

    public shared (msg) func whoami() : async Text {
        return Principal.toText(msg.caller);
    };

    public shared (msg) func logon() : async LogonInfo {

        // if no manager, set manager in the process
        switch(DCEmanager) {
            case (null) {
                DCEmanager := ?msg.caller;
            };
            case (?_) {
            };
        };

        // gather info
        var id = Principal.toText(msg.caller);
        var name = switch (nameTable.get(msg.caller)) {
            case (null) {""};
            case (?name) {name}
        };
        _create_account(msg.caller);  // Ensure account exists
        let account = accounts.get(msg.caller);
        let acc = switch (account) {
            case (null) { {orange=0; green=0;} : Account};
            case (?acc) {acc};
        };

        return {
            id = id;
            name = name;
            orange = acc.orange;
            green = acc.green;
        };

    };
};
