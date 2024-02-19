// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/**
 * @title UnlimitedSupplyNFT
 * @dev Non-fungible token implementation with only expiry times.
 **/
contract limitedSupplyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    /**
     * @dev Default expiry time for newly minted tokens.
     */
    uint256 public defaultExpiryTime;
    uint256 public maxSupply = 15000;

    uint public  PRICE;
    // change the imput pricce

    /**
     * @dev Expiry time for each token ID.
     */
    mapping(uint256 => uint256) private _expiryTimes;
    event MintTimeUpdated(uint256 newTimestamp);

    /**
     * @dev Throws if the current token count is at or above the max supply.
     * @dev Throws if the current block timestamp is less than the default expiry time.
     **/
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC721(name, symbol) Ownable(initialOwner) {
        defaultExpiryTime = 10 minutes;
        PRICE ;
    }

    //The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address payable Owner;
        uint256 price;
        bool currentlyListed;
    }

    //the event emitted when a token is successfully listed
    event TokenListedSuccess(
        uint256 indexed tokenId,
        address Owner,
        uint256 price,
        bool currentlyListed
    );

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => ListedToken) private idToListedToken;

    // Modifier to check if minting is allowed
    modifier mintable() {
        require(
            block.timestamp > defaultExpiryTime,
            "Cannot mint until after the default expiry time"
        );
        require(_tokenIds.current() < maxSupply, "Max supply reached");
        require(msg.value == 0.0001 ether, "Insufficient funds to mint NFT");
        _;
    }

    function updateListPrice(uint256 _listPrice) public payable onlyOwner {
        PRICE = _listPrice;
    }
    function updaTotalSupply(uint256 _supply) public payable onlyOwner {
        maxSupply = _supply;
    }

    function getListPrice() public view returns (uint256) {
        return PRICE;
    }

    function getLatestIdToListedToken()
        public
        view
        returns (ListedToken memory)
    {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getListedTokenForId(
        uint256 tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @notice Mints a new NFT.
     * @dev Minting is restricted by the `mintable` modifier.
     * @param recipient The address receiving the minted NFT.
     * @param tokenURI The URI for the metadata of the NFT.
     * @return tokenId The ID of the newly minted NFT.
     */
    function mintNFT(
        address recipient,
        string memory tokenURI
    ) public payable mintable returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();

        _safeMint(recipient, newItemId);

       
        _setTokenURI(newItemId, tokenURI);

         uint256 price = 0.0001 ether;

        createListedToken(newItemId, price);
        // Set the expiry time for the token
        _expiryTimes[newItemId] = block.timestamp + defaultExpiryTime;
        return newItemId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        //Make sure the sender sent enough ETH to pay for listing
        // require(msg.value == PRICE, "Please send the correct price");
        //Just sanity check
        require(price > 0, "Make sure the price isn't negative");


        //Update the mapping of tokenId's to Token details, useful for retrieval functions
        idToListedToken[tokenId] = ListedToken(
            tokenId,
           payable (msg.sender),
            price,
            true
        );

        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(
            tokenId,
            msg.sender,
            price,
            true
        );
    }

    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint currentIndex = 0;
        uint currentId;
        //at the moment currentlyListed is true for all, if it becomes false in the future we will
        //filter out currentlyListed == false over here
        for (uint i = 0; i < nftCount; i++) {
            currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    //Returns all the NFTs that the current user is owner or Owner in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].Owner == msg.sender
            ) {
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].Owner == msg.sender
            ) {
                currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @notice Burns a specific NFT.
     * @dev Only the owner or an approved operator can burn NFTs.
     * @param _tokenId The ID of the NFT to be burned.
     */
    function burn(uint256 _tokenId) public onlyOwner {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "ERC721: Caller is not owner nor approved"
        );
        emit DebugOwnershipStatus(
        _msgSender(),
        ownerOf(_tokenId),
        getApproved(_tokenId)
    );
        _burn(_tokenId);
    }

event DebugOwnershipStatus(
    address caller,
    address tokenOwner,
    address approvedAddress
);
    /**
     * @notice Checks if an NFT is expired.
     * @dev Returns true if the NFT's expiry time has passed.
     * @param tokenId The ID of the NFT to check.
     * @return bool True if the NFT is expired, false otherwise.
     */
    function isExpired(uint256 tokenId) public view returns (bool) {
        return block.timestamp >= _expiryTimes[tokenId];
    }

    /**
     * @notice Burns an NFT if it is expired.
     * @dev This function checks if the NFT is expired and burns it if true.
     * @param tokenId The ID of the NFT to check and burn.
     */
    function burnIfExpired(uint256 tokenId) public {
        require(isExpired(tokenId), "Token has not yet expired");
        burn(tokenId);
    }

    /**
     * @notice Updates the default expiry time for newly minted tokens.
     * @dev Can only be called by the contract owner.
     * @param _timestamp The new default expiry time in seconds.
     */
    function updateExpiryTime(uint256 _timestamp) public onlyOwner {
        defaultExpiryTime = _timestamp;
        emit MintTimeUpdated(_timestamp);
    }

    /**
     * @notice Periodically check and burn expired NFTs.
     * @dev This function can be called by anyone and is used to periodically check and burn expired NFTs.
     */
    mapping(uint256 => address) private _owners;

    function _exists(uint256 tokenId) internal view returns (bool) {
        return ownerOf(tokenId) != address(0);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function checkAndBurnExpiredNFTs() public {
        // Start from the highest possible token ID and go downwards
        uint256 totalTokens = totalSupply();

        // Iterate in reverse to handle removal of tokens
        for (uint256 i = totalTokens; i > 0; i--) {
            // Check if the token exists before checking if it's expired
            if (_exists(i) && isExpired(i)) {
                burn(i);
            }
        }
    }

    function withdraw() public payable  onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0, "No balance to withdraw");

        payable(owner()).transfer(balance);
    }
}

//0x3107c6B2493179C0b1503E31e3C427C92C8b7d12 - half functions(org)

//0x664bC895e1d22c47a038993Fd8cA4D30d86b0292


//mainnet -polygon : 0xAE036387675433aEcDF19214e49Aa042bf9C331f