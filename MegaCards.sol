pragma solidity ^0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}


/**
 * @title ERC721 Non-Fungible Token Standard basic interface
 */
contract ERC721 {
  event Transfer(
    address indexed _from,
    address indexed _to,
    uint256 _tokenId
  );
  event Approval(
    address indexed _owner,
    address indexed _approved,
    uint256 _tokenId
  );
  event ApprovalForAll(
    address indexed _owner,
    address indexed _operator,
    bool _approved
  );

  function balanceOf(address _owner) public view returns (uint256 _balance); //imp
  function ownerOf(uint256 _tokenId) public view returns (address _owner);  //imp
  function exists(uint256 _tokenId) public view returns (bool _exists);  //imp

  function approve(address _to, uint256 _tokenId) public;  //imp borrowed
  function getApproved(uint256 _tokenId)                    //imp borrowed
    public view returns (address _operator);

  function setApprovalForAll(address _operator, bool _approved) public; //imp borrowed
  function isApprovedForAll(address _owner, address _operator) //imp borrowed
    public view returns (bool);

  function transferFrom(address _from, address _to, uint256 _tokenId) public; //imp borrowed
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) public;

}

contract MegaCards is ERC721 {
  /*** CONSTANTS ***/

  string public constant name = "MegaCards";
  string public constant symbol = "MgCd";

  bytes4 constant InterfaceID_ERC165 =
    bytes4(keccak256('supportsInterface(bytes4)'));

  bytes4 constant InterfaceID_ERC721 =
    bytes4(keccak256('name()')) ^
    bytes4(keccak256('symbol()')) ^
    bytes4(keccak256('totalSupply()')) ^
    bytes4(keccak256('balanceOf(address)')) ^
    bytes4(keccak256('ownerOf(uint256)')) ^
    bytes4(keccak256('approve(address,uint256)')) ^
    bytes4(keccak256('transfer(address,uint256)')) ^
    bytes4(keccak256('transferFrom(address,address,uint256)')) ^
    bytes4(keccak256('tokensOfOwner(address)'));


  /*** DATA TYPES ***/

  struct Token {
    uint256  megaCardSetId;
    uint8  megaCardInSetId;
  }

  struct MegaCardSet {
      string setRefrenceUrl;
      uint8 cardsInSet;
      uint256 priceForSet;
  }

  /*** STORAGE ***/

  Token[] tokens;
  MegaCardSet[] sets;

  mapping (uint256 => address) public tokenIndexToOwner;
  mapping (address => uint256) ownershipTokenCount; //Hmm... I feel like 
  //we should generate tokenCount on the fly when requested 
  mapping (uint256 => address) public tokenIndexToApproved;

  // Mapping from token ID to approved address
  mapping (uint256 => address) internal tokenApprovals;

 // Mapping from owner to operator approvals
  mapping (address => mapping (address => bool)) internal operatorApprovals;


  mapping(uint256 => uint256)  public tokenSalePrice;
  mapping(uint256 => string)    public tokenModifications;

  address public admin;

  /*** EVENTS ***/

  event Mint(address owner, uint256 tokenId);
  event Sale(address owner, address buyer, uint256 tokenId, uint256 price);


  /*** Modifiers ***/

  modifier onlyAdmin() {
    require(msg.sender == admin);
    _;
  }

  /*** INTERNAL FUNCTIONS ***/

  function _random(uint8 _range) private view returns (uint8) {
    return uint8(uint256(keccak256(block.timestamp, block.difficulty))%_range);
  }

  function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return tokenIndexToOwner[_tokenId] == _claimant;
  }

  function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return tokenIndexToApproved[_tokenId] == _claimant;
  }

  function _approve(address _to, uint256 _tokenId) internal {
    tokenIndexToApproved[_tokenId] = _to;
    emit Approval(tokenIndexToOwner[_tokenId], tokenIndexToApproved[_tokenId], _tokenId);
  }

  function _transfer(address _from, address _to, uint256 _tokenId) internal {
    ownershipTokenCount[_to]++;
    tokenIndexToOwner[_tokenId] = _to;

    if (_from != address(0)) {
      ownershipTokenCount[_from]--;
      delete tokenIndexToApproved[_tokenId];
    }

    emit Transfer(_from, _to, _tokenId);
  }

  function _mint(address _owner, uint256 _megaCardSetId ) internal returns (uint256 tokenId) {
    Token memory token = Token({
      megaCardSetId: _megaCardSetId, // Need to make these psudo-random
      megaCardInSetId: _random(sets[_megaCardSetId].cardsInSet)  //Need to make these pudo-random, use block time
    });
    tokenId = tokens.push(token) - 1;

    emit Mint(_owner, tokenId);

    _transfer(0, _owner, tokenId);
  }


  /*** ERC721 IMPLEMENTATION ***/

  function supportsInterface(bytes4 _interfaceID) external pure returns (bool) {
    return ((_interfaceID == InterfaceID_ERC165) || (_interfaceID == InterfaceID_ERC721));
  }

  function totalSupply() public view returns (uint256) {
    return tokens.length;
  }

  function balanceOf(address _owner) public view returns (uint256) {
    return ownershipTokenCount[_owner]; //Hmm, I really want to get rind of the 
    //ownershipCount and make this get generated by read-only search
  }

  function ownerOf(uint256 _tokenId) public view returns (address _owner) {
    _owner = tokenIndexToOwner[_tokenId];
    require(_owner != address(0));
  }

  function exists(uint256 _tokenId) public view returns (bool _result){
      if(tokenIndexToOwner[_tokenId] == 0){
          _result = false;
      } else {
          _result = true;
      }
  }


  /**
   * @dev Approves another address to transfer the given token ID
   * The zero address indicates there is no approved address.
   * There can only be one approved address per token at a given time.
   * Can only be called by the token owner or an approved operator.
   * @param _to address to be approved for the given token ID
   * @param _tokenId uint256 ID of the token to be approved
   */
  function approve(address _to, uint256 _tokenId) public {
    address owner = ownerOf(_tokenId);
    require(_to != owner);
    require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

    tokenApprovals[_tokenId] = _to;
    emit Approval(owner, _to, _tokenId);
  }

  /**
   * @dev Gets the approved address for a token ID, or zero if no address set
   * @param _tokenId uint256 ID of the token to query the approval of
   * @return address currently approved for the given token ID
   */
  function getApproved(uint256 _tokenId) public view returns (address) {
    return tokenApprovals[_tokenId];
  }

  /**
   * @dev Sets or unsets the approval of a given operator
   * An operator is allowed to transfer all tokens of the sender on their behalf
   * @param _to operator address to set the approval
   * @param _approved representing the status of the approval to be set
   */
  function setApprovalForAll(address _to, bool _approved) public {
    require(_to != msg.sender);
    operatorApprovals[msg.sender][_to] = _approved;
    emit ApprovalForAll(msg.sender, _to, _approved);
  }

  /**
   * @dev Tells whether an operator is approved by a given owner
   * @param _owner owner address which you want to query the approval of
   * @param _operator operator address which you want to query the approval of
   * @return bool whether the given operator is approved by the given owner
   */
  function isApprovedForAll(
    address _owner,
    address _operator
  )
    public
    view
    returns (bool)
  {
    return operatorApprovals[_owner][_operator];
  }

 /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   *
   * Requires the msg sender to be the owner, approved, or operator
   * @param _from current owner of the token
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint256 ID of the token to be transferred
  */
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
    //I should actually... you know... implement this or something 
    // canTransfer(_tokenId) 
    // solium-disable-next-line arg-overflow
    _transfer(_from, _to, _tokenId);
  }

  function transfer(address _to, uint256 _tokenId) external {
    require(_to != address(0));
    require(_to != address(this));
    require(_owns(msg.sender, _tokenId));

    _transfer(msg.sender, _to, _tokenId);
  }

  function transferFrom(address _from, address _to, uint256 _tokenId) public {
    require(_to != address(0));
    require(_to != address(this));
    require(_approvedFor(msg.sender, _tokenId));
    require(_owns(_from, _tokenId));

    _transfer(_from, _to, _tokenId);
  }

  function tokensOfOwner(address _owner) external view returns (uint256[]) {
    uint256 balance = balanceOf(_owner);

    if (balance == 0) {
      return new uint256[](0);
    } else {
      uint256[] memory result = new uint256[](balance);
      uint256 maxTokenId = totalSupply();
      uint256 idx = 0;

      uint256 tokenId;
      for (tokenId = 1; tokenId <= maxTokenId; tokenId++) {
        if (tokenIndexToOwner[tokenId] == _owner) {
          result[idx] = tokenId;
          idx++;
        }
      }
    }

    return result;
  }


  /*** OTHER EXTERNAL FUNCTIONS ***/

  function payout(address _to) public onlyAdmin {
    _to.transfer(address(this).balance);
  }

  function mint(uint256 _megaCardSetId) external payable returns (uint256) {
    MegaCardSet memory set = sets[_megaCardSetId] ; 
    if(msg.value >= set.priceForSet){
        return _mint(msg.sender, _megaCardSetId);
    }
  }

  function getToken(uint256 _tokenId) external view returns (uint256 setId, uint8 cardInSetId, string modifications, uint256 price) {
    Token memory token = tokens[_tokenId];

    setId = token.megaCardSetId;
    cardInSetId = token.megaCardInSetId;
    modifications = tokenModifications[_tokenId];
    price = tokenSalePrice[_tokenId];
  }
  
  function mintSet(uint8 _cardsInSet, uint256 _priceForSet, string _refrenceUrl ) external onlyAdmin returns (uint256 setId){
      MegaCardSet memory set = MegaCardSet({
        setRefrenceUrl: _refrenceUrl,
        cardsInSet: _cardsInSet,
        priceForSet: _priceForSet 
      });
  
    setId = sets.push(set) - 1;
  }
  
  function modifyToken(uint256 _tokenId, string _modification) external onlyAdmin {
      tokenModifications[_tokenId] = _modification;
  }
  
  function setTokenPrice(uint256 _tokenId, uint256 _price) external {
      if(_owns(msg.sender, _tokenId)){
          tokenSalePrice[_tokenId] = _price;
      }
  }
  
  function buyToken(uint256 _tokenId) external payable  {
      if(tokenSalePrice[_tokenId] > 0){
          if(msg.value >= tokenSalePrice[_tokenId]){
              address payee = tokenIndexToOwner[_tokenId];
              tokenIndexToOwner[_tokenId] = msg.sender;
              tokenSalePrice[_tokenId] = 0;
              payee.transfer(msg.value);
          }
      }
  }
  
}

