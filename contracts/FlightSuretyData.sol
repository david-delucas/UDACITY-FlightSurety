pragma solidity ^0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    address private contractApp;
    bool private operational;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) private authorizedCallers;

    // the contract level funds (not allocated to individual airlines)
    uint256 private contractFunds = 0 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        address [] insured;
    }

    struct Passenger {
        bool isRegistered;
        mapping (bytes32 => uint) insuranceValue;
        uint balance;
    }

    mapping(address => Passenger) private passengers;
    mapping(bytes32 => Flight) public flights;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineAdded(address indexed account);
    event AirlineStatusChanged(address indexed account);
    event AirlineRemoved(address indexed account);
    event MultiCallStatusChanged(address indexed account);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
    (address firstAirline
    )

    public
    {
        contractOwner = msg.sender;
        airlines[firstAirline] = Airline(firstAirline, AIRLINE_STATE_REGISTERED, "First Airline", 0, new address[](0), 0);
        operational = true;
    }

    function authorizeCaller(address _appContractOwner) external requireIsOperational requireContractOwner {
        contractApp = _appContractOwner;
    }


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized()
    {
        require(msg.sender == contractApp, "Caller is not authorized");
        _;
    }

    modifier requireCallerAuthorized()
    {
        require(authorizedCallers[msg.sender] || (msg.sender == contractOwner), "Caller is not authorised");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        operational = mode;        
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    uint AIRLINE_STATE_NOT_REGISTERED = 0;
    uint AIRLINE_STATE_APPLIED = 1;
    uint AIRLINE_STATE_REGISTERED = 2;
    uint AIRLINE_STATE_PAID = 3;

    enum AirlineState {
        NotRegistered,
        Applied,
        Registered,
        Paid
    }

    struct Airline {
        address airlineAddress;
        uint state;
        string name;
        uint256 funds;
        address[] approvals;
        uint approvalsCount;
    }

    mapping(address => Airline) internal airlines;
    uint internal totalPaidAirlines = 0;

    function getAirlineState(address airline)
    external
    view
    requireCallerAuthorized
    returns (uint)
    {
        return airlines[airline].state;
    }


    function getTotalPaidAirlines()
    external
    view
    requireCallerAuthorized
    returns (uint)
    {
        return totalPaidAirlines;
    }



    function setAirlaneStatus(address account, uint mode) internal{
        uint old_status = airlines[account].state;
        airlines[account].state = mode;
        if(mode == AIRLINE_STATE_PAID) totalPaidAirlines += 1;
        if( ( old_status == AIRLINE_STATE_PAID ) && ( mode != AIRLINE_STATE_PAID ) ) totalPaidAirlines -= 1;
        emit AirlineStatusChanged(account);
    }



    function isActive(address airline) public view returns (bool) {
        return (
            airlines[airline].state  == AIRLINE_STATE_REGISTERED ||
            airlines[airline].state  == AIRLINE_STATE_PAID
        );
    }


    function isRegistered(address airline) public view returns (bool) {
            airlines[airline].state  == AIRLINE_STATE_REGISTERED;
    }

    function isPaid(address airline) public view returns (bool) {
        return airlines[airline].state  == AIRLINE_STATE_PAID;
    }

    function addAirline(address account, string memory name) internal {
        airlines[account] = Airline(account, AIRLINE_STATE_REGISTERED, name, 0, new address[](0), 0);
        emit AirlineAdded(account);
    }

    // Define a function 'addAirline' that adds this role
    function addAirline(address account, address origin, string memory name) public {
        require(isAirline(origin), "Only Airlines");
        addAirline(account,name);
    }


    // Define a function 'isAirline' to check this role
    function isAirline(address account) public view returns (bool) {
        return airlines[account].airlineAddress != address(0) ; 
       /*    return (   airlines[account].state  == AIRLINE_STATE_REGISTERED ||
            airlines[account].state  == AIRLINE_STATE_PAID ||
            airlines[account].state  == AIRLINE_STATE_APPLIED );*/
    }


    function getMultiCallsCount(address account)
    internal
    view
    returns (uint)
    {
        return airlines[account].approvalsCount;
    }


    function pushToMultiCalls(address account, address callerAccount,string memory name) internal {
        if ( isAirline(account) ) {
            airlines[account].approvals.push(callerAccount);
            airlines[account].approvalsCount += 1;
            emit MultiCallStatusChanged(account);
            //return 1;
        } else {
            airlines[account] = Airline(account, 111111 + AIRLINE_STATE_APPLIED, name, 0, new address[](0), 1);
            airlines[account].approvals.push(callerAccount);
            emit AirlineAdded(account);
            //return 2;
        }
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
    (
        address newAirline,
        address callerAirline,
        string calldata name
    )
    external
    requireIsOperational
    requireIsCallerAuthorized
    returns (bool success, uint256 votes, uint _totalPaidAirlines, uint256 Majority, uint exist) 
    {
        uint _exist = 0;
        uint _exist2 = 0;
        //require(isAirline(callerAirline), "Caller is not an Airline");
        require(isActive(callerAirline), "Caller is not an active Airline");
        require(isPaid(callerAirline), "Caller is not a funded Airline");
        require(!isAirline(newAirline), "New Airline is already registered");
        if (totalPaidAirlines < 4) {
            addAirline(newAirline, callerAirline, name);
            return (true, 0, totalPaidAirlines, 0, _exist);
        } else {
            bool isDuplicate = false;
            Majority = totalPaidAirlines.div(2);
            if (isAirline(newAirline)) {
                _exist +=airlines[callerAirline].state;
                _exist +=airlines[newAirline].state;
            }
            for (uint c = 0; c <  getMultiCallsCount(newAirline); c++) {
                _exist +=10;
                if (airlines[newAirline].approvals[c] == callerAirline) {
                    isDuplicate = true;
                    _exist +=100;
                    break;
                }
            }
            require(!isDuplicate, "Airline has already called this function.");
            pushToMultiCalls(newAirline,callerAirline, name);

            if (isAirline(newAirline)) {
                _exist +=airlines[callerAirline].state;
                _exist +=airlines[newAirline].state;
            }


            votes = getMultiCallsCount(newAirline);            
            //multiCalls.push(callerAirline);
            if (votes >= Majority) {
                addAirline(newAirline, callerAirline, name);
                return (true, votes, totalPaidAirlines, Majority, _exist);
            }
        }
        return (false, votes, totalPaidAirlines, Majority, _exist);
    }

    function activateAirline(address account, uint mode)
    public
    requireIsOperational
    requireIsCallerAuthorized
    returns (bool success){
        require(isAirline(account), "Caller is not an Airline");
        setAirlaneStatus(account, mode);
        return (true);
    }

    function registerFlight
    (
        address _airline,
        string calldata _flight,
        uint256 _timestamp
    )
    external
    requireIsOperational
    requireIsCallerAuthorized
    {
        require(isAirline(_airline), "Caller is not an Airline");
        require(isActive(_airline), "Caller is not an active Airline");
        bytes32 _key = getFlightKey(_airline, _flight);
        flights[_key] = Flight(
            {
            isRegistered : true,
            statusCode : 0,
            updatedTimestamp : _timestamp,
            airline : _airline,
            insured : new address[](0)
            }
        );
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                              address _airline,
                              uint256 _fund  
                            )
                            public
                            payable
                            requireIsOperational
    {
        airlines[_airline].funds = airlines[_airline].funds.add(_fund);
        if (airlines[_airline].funds >= 10 ) {
            setAirlaneStatus(_airline, AIRLINE_STATE_PAID);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight/*,
                            uint256 timestamp*/
                        )
                        view
                        internal
			requireIsOperational
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight/*, timestamp*/));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() 
                            external 
                            payable 
                            
    {
        contractFunds = contractFunds.add(msg.value);
    }
    receive() 
                            external 
                            payable 
                            
    {
        contractFunds = contractFunds.add(msg.value);
    }



}

