pragma solidity ^0.4.25;

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

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
    (
    )

    public
    {
        contractOwner = msg.sender;
        airlines[contractOwner] = Airline(contractOwner, AirlineState.Paid, "First Airline", 0);
        totalPaidAirlines++;
        operational = true;

    }

    function authorizeCaller(address _appContractOwner) external requireIsOperational requireContractOwner {
        contractOwner = _appContractOwner;
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


    enum AirlineState {
        Applied,
        Registered,
        Paid
    }

    struct Airline {
        address airlineAddress;
        AirlineState state;
        string name;

        mapping(address => bool) approvals;
        uint8 approvalCount;
    }

    mapping(address => Airline) internal airlines;
    uint256 internal totalPaidAirlines = 0;

    function getAirlineState(address airline)
    external
    view
    requireCallerAuthorized
    returns (AirlineState)
    {
        return airlines[airline].state;
    }


    function setAirlaneStatus(address account, AirlineState mode) internal{
        airlines[account].state = mode;
        if(mode == AirlineState.Paid) totalPaidAirlines += 1;
        else totalPaidAirlines -= 1;
        emit AirlineStatusChanged(account);
    }



    function isActive(address airline) public view returns (bool) {
        return airlines[airline].state  == AirlineState.Registered;
    }


    function isRegistered(address airline) public view returns (bool) {
        return airlines[airline].state  == AirlineState.Registered;
    }

    function isPaid(address airline) public view returns (bool) {
        return airlines[airline].state  == AirlineState.Paid;
    }

    function addAirline(address account) internal {
        airlines[account].airlineAddress=account;
        emit AirlineAdded(account);
    }

    // Define a function 'addAirline' that adds this role
    function addAirline(address account, address origin) public {
        require(isAirline(origin), "Only Airlines");
        addAirline(account);
    }


    // Define a function 'isAirline' to check this role
    function isAirline(address account) public view returns (bool) {
        return airlines[account].airlineAddress > 0;
    }

    address[] multiCalls = new address[](0);
   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
    (
        address newAirlines,
        address oldAirlines
    )
    external
    requireIsOperational
    requireIsCallerAuthorized
    returns (bool success, uint256 votes)
    {
        require(isAirline(oldAirlines), "Caller is not an Airline");
        require(isActive(oldAirlines), "Caller is not an active Airline");
        if (totalPaidAirlines < 4) {
            addAirline(newAirlines, oldAirlines);
            return (true, 0);
        } else {
            bool isDuplicate = false;
            uint M = totalPaidAirlines / 2;
            for (uint c = 0; c < multiCalls.length; c++) {
                if (multiCalls[c] == oldAirlines) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Airline has already called this function.");

            multiCalls.push(oldAirlines);
            if (multiCalls.length >= M) {
                addAirline(newAirlines, oldAirlines);
                votes = multiCalls.length;
                multiCalls = new address[](0);
                return (true, votes);
            }

        }

        return (false, 0);
    }

    function activateAirline(address account, AirlineState mode)
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
        string _flight,
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
                            )
                            public
                            payable
    {
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
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

