// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";

contract IyNFT is ERC721("IyNFT", "INFT") {
    function tokenURI(
        uint256 id
    ) public view virtual override returns (string memory) {
        return "Not real";
    }

    function mint(address recipient, uint256 tokenId) public payable {
        _mint(recipient, tokenId);
    }
}
