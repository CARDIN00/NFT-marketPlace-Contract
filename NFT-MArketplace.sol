// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//IERC 721 contract
contract ERC721{
    //name and symbol

    string public tokenName = "basicNFT";
    string public tokenSymbol = "BNFT";

    // MAPPINGS

    mapping (uint => address) public tokenOwner ;// tokenId to address
    mapping (address => uint) public Balance;// balance of address
    mapping(uint =>address) public tokenApproval; // tokenId to approved address
    mapping(address  => mapping(address => bool)) public approveOperator; // approve the operator of the tokens

    // EVENTS

    event transfer(address indexed From, address indexed To, uint TokenId);
    event approval(address indexed from, address indexed operator, bool approval);
    event approvedToken(address indexed owner, address indexed  operator, uint indexed tokeId);


    // FUNCTIONS

    //to see the balance of any address
    function balanceOf(address _user)public view returns (uint){
        require(_user != address(0),"enter a valid address");
        return Balance[_user];
    }

    //to see the owner of any token Id
    function OwnerOf(uint _token)public view returns (address){
        address owner =tokenOwner[_token];
        require(owner != address(0));
        return  tokenOwner[_token];
    }

    // mint token
    function mint(
    address _to,
    uint _tokenId
    ) public returns(bool)
    {
        require(_to != address(0), "cant mint to invalid address");
        require(tokenOwner[_tokenId] == address(0),"token-Id already exists");

        tokenOwner[_tokenId] =_to;//assign ownership
        Balance[_to] += 1;
        
        emit transfer(address(0), _to, _tokenId);
        return true;
    }

    //transfer the token
    function TransferToken( 
    address _oldOwner,
    address _newOwner,
    uint _tokenId
     )public returns(bool)
     {
        require(_newOwner != address(0), "enter a valid address");
        require(_oldOwner ==msg.sender,"only the owner can transfer");
        require(tokenOwner[_tokenId] == _oldOwner,"token id does not belong to the sender");

        Balance[_oldOwner] -= 1;
        Balance[_newOwner] += 1;
        tokenOwner[_tokenId] =_newOwner;

        emit transfer(_oldOwner, _newOwner, _tokenId);
        return true;
    }

    //approve to spend SPECIFIED tokens
    function approve(address _operator, uint _tokeId)public returns (bool){
        address owner = tokenOwner[_tokeId];
        require(owner != _operator," can not approve self");
        require(owner ==msg.sender,"only the owner himselg can approve");

        tokenApproval[_tokeId] = _operator;
        emit approvedToken(msg.sender, _operator, _tokeId);
        return  true;

    }

    //APPROVE someone else to spend all your tokens
    function setApproveForAll(address _operator) public {
        require(msg.sender != _operator,"Enter another address that can act as your proxy");
        approveOperator[msg.sender][_operator] = true;
        
        emit approval(msg.sender, _operator, true);
        

    }

    //to check is the operator is approved for all the tokens
    function isApprovedForAll(address _operator, address _owner) public view returns (bool){
        return approveOperator[_owner][_operator];
    }

   
    //clear approval
    function clearApproval(uint tokenid) public {

        address owner = tokenOwner[tokenid];
        require(owner ==msg.sender,"only the owner can clear the approval");
        if(tokenApproval[tokenid] != address(0)){
            tokenApproval[tokenid] = address(0);
        }
    }
}


//Contract => A SIMPLE MARKETPLACE
//mint new NFT using existing contract
//list the NFT for sale
//Buy NFT put up for sale
//Transfer OwnerShip upon successFul purchase

contract marketplace is ERC721{

    address public owner;
    uint public MarketfeePercentage = 2;

    constructor(){
        owner =msg.sender;
    }

    //struct for the token details
    struct Listing{
        address seller;
        uint price;
    }

    //MAPPINGS
    mapping (uint => Listing) public listings;

    mapping(address => uint ) public pendingWithdrawal;

    // EVENTS
    event feechange(address indexed changer, uint amount);
    event Listed(address indexed seller, uint tokenId, uint indexed time);
    event Sold(address indexed seller, address indexed buyer, uint price, uint indexed time);
    event cancel(address indexed canceller, uint tokenId , uint indexed time);
    event withdrawals(address indexed person, uint amount);
    // MODIFIER
    modifier ownercall(){
        require(msg.sender==owner);
        _;
    }

    // FUNCTIONS

    //set the market fee
    function changeMarketFee(uint _newFeePercentage) public ownercall{
        require(_newFeePercentage < 8,"the fees is too high");
        MarketfeePercentage = _newFeePercentage;

    }

    //list token for sale
    function listToken(uint _tokenId, uint _price) public{
        require(OwnerOf(_tokenId) == msg.sender, "you are not the owner of this token id");
        require(tokenApproval[_tokenId] == msg.sender,"you are not approved or the owner"); // checks if the person is approved
        require(_price > 0, "the price of the token can not be zero");

        approve(address(this), _tokenId);//approve the contract to handle the token 
        uint time = block.timestamp;

        listings[_tokenId] = Listing(msg.sender, _price);
        emit Listed(msg.sender, _tokenId, time);
    }

    //cancel the listing
    function cancelListing(uint _tokenId) public {
        Listing memory listedItem = listings[_tokenId];
        require
        (listedItem.seller == msg.sender || listedItem.seller == OwnerOf(_tokenId),
        "you are not the owner or the approved person"
        );

        require(listedItem.price>0,"the item is not listed");
        delete listings[_tokenId];//delete the linting

        uint time = block.timestamp;
        emit cancel(msg.sender, _tokenId, time);

    }

    //Buy the token put up for sale
    function BuyToken(uint _tokenId)public payable {
        Listing memory listedItem = listings[_tokenId];
        uint feeAmount = (listedItem.price * MarketfeePercentage) /100;
        uint totalAmount = listedItem.price + feeAmount;


        require(listedItem.price >0,"the token id is not listed for sale");
        require(msg.value>= totalAmount ,"insufficient balance");
        
        // adding to the pending withdrawal of the owner and the seller
        pendingWithdrawal[owner] += feeAmount;// pending for the owner of the contract
        pendingWithdrawal[OwnerOf(_tokenId)] += listedItem.price;

        //if the buyer sends more than required money
        uint excessAmount = msg.value - totalAmount;
        if (excessAmount > 0) {
        payable(msg.sender).transfer(excessAmount);
        }


        // transfer the token
        TransferToken(listedItem.seller, msg.sender, _tokenId);
        uint time = block.timestamp;
        
        emit Sold(listedItem.seller, msg.sender, totalAmount, time);

        //delete from the sales listings
        delete listings[_tokenId];
        
    }

    //Withdraw the money for the sold item
    function withdraw() public {
        uint amount = pendingWithdrawal[msg.sender];
        require(amount > 0," no amount pending to be withdrawn");

        //transfer the money
        payable(msg.sender).transfer(amount);
        emit withdrawals(msg.sender, amount);

        //set the pending withdrawal to zero
        pendingWithdrawal[msg.sender]= 0;
    }


}