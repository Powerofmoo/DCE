import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";

actor {

    // Managers
    var DCEmanager : ?Principal = null;
    var managers : [Principal] = [];

    // Initial amount constants
    let startAmountOrange = 20;
    let startAmountGreen = 20;

    // LogonInfo structure
    type LogonInfo = {
        id: Text;
        name: Text;
        orange: Nat;
        green: Nat;
    };

    // Account structure
    type Account = {
        orange: Nat;
        green: Nat;
    };

    // Account TrieMap
    var accounts = TrieMap.TrieMap<Principal, Account>(Principal.equal, Principal.hash);

    // Name table TrieMap
    var nameTable = TrieMap.TrieMap<Principal, Text>(Principal.equal, Principal.hash);

    // Transfer structure
    type Transfer = {
        authorization: Principal;
        from: Principal;
        to: Principal;
        orange: Nat;
        green: Nat;
        reason: Text;
        dateTime: Text;
    };

    // Transfer Buffer
    var transfers: Buffer.Buffer<Transfer> = Buffer.Buffer<Transfer>(10);

    // TransferInfo structure
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

    // ReferStatus type
    type ReferStatus = {#Open; #Confirmed; #Blocked;};

    // Referral structure
    type Referral = {
        id: Principal;
        status: ReferStatus;
    };

    // Referral TrieMaps
    var emailReferrals = TrieMap.TrieMap<Text, Referral>(Text.equal, Text.hash);
    var telegramReferrals = TrieMap.TrieMap<Text, Referral>(Text.equal, Text.hash);

    // Temporary accounts TrieMaps
    var emailAccounts = TrieMap.TrieMap<Text, Account>(Text.equal, Text.hash);
    var telegramAccounts = TrieMap.TrieMap<Text, Account>(Text.equal, Text.hash);


    // Create account if it doesn't exist
    private func _createAccount(principal: Principal) : () {
        if (null == accounts.get(principal)) {
            let account_new : Account = {
                orange = startAmountOrange;
                green = startAmountGreen;
            };
            accounts.put(principal, account_new);
        }
    };

    // Add transfer to the buffer
    private func _addTransfer(auth: Principal, from: Principal, to: Principal, orange: Nat, green: Nat, reason: Text) {
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

    // Transfer between accounts
    private func _transfer(auth: Principal, from: Principal, to: Principal, orange: Nat, green: Nat, reason: Text) : Bool {
        // Ensure both accounts exist
        _createAccount(from);
        _createAccount(to);

        // Check if sender has sufficient balance
        let fromValues = switch (accounts.get(from)) {
            case (?values) { values };
            case (null) { return false; };
        };

        if (fromValues.orange < orange or fromValues.green < green) {
            return false;
        };

        // Deduct from sender and add to receiver
        let toValues = switch (accounts.get(to)) {
            case (?values) { values };
            case (null) { {orange = 0; green = 0}; };
        };

        accounts.put(from, {orange = fromValues.orange - orange; green = fromValues.green - green});
        accounts.put(to, {orange = toValues.orange + orange; green = toValues.green + green});

        // Add transfer to history
        _addTransfer(auth, from, to, orange, green, reason);

        return true;
    };

    // Mint new tokens
    private func _mint(auth: Principal, to: Principal, orange: Nat, green: Nat, reason: Text) : Bool {
        // Ensure account exists
        _createAccount(to);

        // Add tokens to the account
        let toValues = switch (accounts.get(to)) {
            case (?values) { values };
            case (null) { {orange = 0; green = 0}; };
        };

        accounts.put(to, {orange = toValues.orange + orange; green = toValues.green + green});

        // Add transfer to history
        _addTransfer(auth, auth, to, orange, green, reason);

        return true;
    }; 

    // Check if caller is a manager
    private func _isManager(id: Principal, extended: Bool) : Bool {
        switch (DCEmanager) {
            case (?manager):
                if (manager == id) {
                    return true;
                };
            default {};
        };

        if (not extended) {
            return false;
        };

        return Array.exists(managers, func (p: Principal) : Bool {
            Principal.equal(p, id);
        });
    };


    // Add a new manager
    public shared (msg) func addManager(newManagerText: Text) : async Bool {
        let newManager = Principal.fromText(newManagerText);

        if (not _isManager(msg.caller, false)) {
            return false;
        }

        if (!Array.contains(managers, newManager)) {
            managers := Array.append<Principal>(managers, [newManager]);
        }

        return true;
    };

    // List all managers
    public shared (msg) func listManagers() : async [Principal] {
        if (not _isManager(msg.caller, false)) {
            return [];
        }
        return managers;
    };

    // Get balance of an account
    public shared (msg) func getBalance(idText: Text) : async Account {
        var id = msg.caller;
        if (idText != "") {
            id := Principal.fromText(idText);
        }

        if (msg.caller != id and not _isManager(msg.caller, true)) {
            return {orange = 0; green = 0;};
        }

        _createAccount(id);  // Ensure account exists
        let optAccount = accounts.get(id);

        let account = switch (optAccount) {
            case (?acc) {acc};
            case (null) { {orange = 0; green = 0;}; };
        };
        return account;
    };

    // Transfer tokens
    public shared (msg) func transfer(toText: Text, orange: Nat, green: Nat, reason: Text) : async Bool {
        let to = Principal.fromText(toText);
        return _transfer(msg.caller, msg.caller, to, orange, green, reason);
    }; 

    // Transaction between accounts (only for managers)
    public shared (msg) func transaction(fromText:Text, toText: Text, orange: Nat, green: Nat, reason: Text) : async Bool {
        let from = Principal.fromText(fromText);
        let to = Principal.fromText(toText);
        if (not _isManager(msg.caller, true)) {
            return false;
        }
        return _transfer(msg.caller, from, to, orange, green, reason);
    }; 

    // Buy tokens (only for managers)
    public shared (msg) func buy(toText: Text, orange: Nat, reason: Text) : async Bool {
        let auth = msg.caller;
        let to = Principal.fromText(toText);
        if (not _isManager(msg.caller, true)) {
            return false;
        }
        return _mint(auth, to, orange, 0, reason);
    }; 

    // Grant tokens (only for managers)
    public shared (msg) func grant(toText: Text, green: Nat, reason: Text) : async Bool {
        let auth = msg.caller;
        let to = Principal.fromText(toText);
        if (green > 10 or not _isManager(msg.caller, true)) {
            return false;
        }
        return _mint(auth, to, 0, green, reason);
    }; 

    // Grant tokens for Telegram referrals
    public shared (msg) func grantTelegram(to: Text, green: Nat, reason: Text) : async Bool {
        let auth = msg.caller;
        if (green > 10) {
            return false;
        }

        let referral = switch (telegramReferrals.get(to)) {
            case (?value) { value };
            case (null) { {id = Principal.fromText(to); status = #Open;} };
        };

        if (referral.status == #Confirmed) {
            return _mint(auth, referral.id, 0, green, reason);
        } else if (referral.status == #Blocked) {
            return false;
        }

        let account = switch (telegramAccounts.get(to)) {
            case (?value) { value };
            case (null) { {orange = 0; green = 0;}; };
        };
        telegramAccounts.put(to, { orange = account.orange; green = account.green + green;});

        return true;
    }; 

    // Grant tokens for Email referrals
    public shared (msg) func grantEmail(to: Text, green: Nat, reason: Text) : async Bool {
        let auth = msg.caller;
        if (green > 10) {
            return false;
        }

        let referral = switch (emailReferrals.get(to)) {
            case (?value) { value };
            case (null) { {id = Principal.fromText(to); status = #Open;} };
        };

        if (referral.status == #Confirmed) {
            return _mint(auth, referral.id, 0, green, reason);
        } else if (referral.status == #Blocked) {
            return false;
        }

        let account = switch (emailAccounts.get(to)) {
            case (?value) { value };
            case (null) { {orange = 0; green = 0;}; };
        };
        emailAccounts.put(to, { orange = account.orange; green = account.green + green;});

        return true;
    }; 

    // Set name for the caller
    public shared (msg) func setName(name: Text) : async Bool {
        nameTable.put(msg.caller, name);
        return true;
    };

    // Get name of the caller
    public shared (msg) func getName() : async Text {
        return switch (nameTable.get(msg.caller)) {
            case (?name) { name };
            case (null) { "" };
        };
    };

    // Claim Telegram referral
    public shared (msg) func claimTelegram(idText: Text, referral: Text) : async Bool {
        var id = msg.caller;
        if (idText != "") {
            id := Principal.fromText(idText);
        }

        if (msg.caller != id and not _isManager(msg.caller, true)) {
            return false;
        }

        let referralInfo = switch (telegramReferrals.get(referral)) {
            case (?value) { value };
            case (null) { {id = id; status = #Open;} };
        };

        if (referralInfo.status == #Confirmed) {
            return true;
        } else if (referralInfo.status == #Blocked) {
            return false;
        }

        telegramReferrals.put(referral, {id = id; status = #Confirmed;});

        let account = switch (telegramAccounts.get(referral)) {
            case (?value) { value };
            case (null) { {orange = 0; green = 0;}; };
        };
        let mintSuccess = _mint(msg.caller, id, 0, account.green, "(from Telegram)" );
        telegramAccounts.delete(referral);

        return mintSuccess;
    };

    // Claim Email referral
    public shared (msg) func claimEmail(idText: Text, referral: Text) : async Bool {
        var id = msg.caller;
        if (idText != "") {
            id := Principal.fromText(idText);
        }

        if (msg.caller != id and not _isManager(msg.caller, true)) {
            return false;
        }

        let referralInfo = switch (emailReferrals.get(referral)) {
            case (?value) { value };
            case (null) { {id = id; status = #Open;} };
        };

        if (referralInfo.status == #Confirmed) {
            return true;
        } else if (referralInfo.status == #Blocked) {
            return false;
        }

        emailReferrals.put(referral, {id = id; status = #Confirmed;});

        let account = switch (emailAccounts.get(referral)) {
            case (?value) { value };
            case (null) { {orange = 0; green = 0;}; };
        };
        let mintSuccess = _mint(msg.caller, id, 0, account.green, "(from email " # referral # ")" );
        emailAccounts.delete(referral);

        return mintSuccess;
    };

    // Lookup name by Principal ID
    private func _lookupName(id: Principal) : Text {
        return switch (nameTable.get(id)) {
            case (?found) { found };
            case (null) { "" };
        };
    };

    // Get transfer history for the caller
    public shared (msg) func showTransfers () : async [TransferInfo] {
        let id = msg.caller;

        var transferInfos: Buffer.Buffer<TransferInfo> = Buffer.Buffer<TransferInfo>(10);
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
                transferInfos.add(transferInfo);
            };
        });

        return Buffer.toArray<TransferInfo>(transferInfos);
    };

    // Get Telegram referral information for debugging
    public func dumpTelegram(id: Text) : async ?Referral {
        return telegramReferrals.get(id);
    };

    // Get Telegram referral account information for debugging
    public func dumpTelegramAccount(id: Text) : async ?Account {
        return telegramAccounts.get(id);
    }; 

    // Get Email referral information for debugging
    public func dumpEmail(id: Text) : async ?Referral {
        return emailReferrals.get(id);
    };

    // Get Email referral account information for debugging
    public func dumpEmailAccount(id: Text) : async ?Account {
        return emailAccounts.get(id);
    }; 

    // Get user info (manager or user)
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

    // Get Principal ID of the caller
    public shared (msg) func whoami() : async Text {
        return Principal.toText(msg.caller);
    };

    // Logon function
    public shared (msg) func logon() : async LogonInfo {

        // If no manager, set manager to the caller
        switch(DCEmanager) {
            case (null) {
                DCEmanager := ?msg.caller;
            };
            case (?_) {
            };
        };

        // Gather user info
        var id = Principal.toText(msg.caller);
        var name = switch (nameTable.get(msg.caller)) {
            case (?name) { name };
            case (null) { "" };
        };

        _createAccount(msg.caller);  // Ensure account exists
        let account = accounts.get(msg.caller);

        let acc = switch (account) {
            case (?acc) {acc};
            case (null) { {orange = 0; green = 0;}; };
        };

        return {
            id = id;
            name = name;
            orange = acc.orange;
            green = acc.green;
        };
    };
};
