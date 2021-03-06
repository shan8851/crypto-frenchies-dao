// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IFakeNFTMarketplace {
    function getPrice() external view returns (uint256);

    /// @dev available() returns whether or not the given _tokenId has already been purchased
    /// @return Returns a boolean value - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    /// @dev purchase() purchases an NFT from the FakeNFTMarketplace
    /// @param _tokenId - the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}

interface ICryptoFrenchiesNFT {
    /// @dev balanceOf returns the number of NFTs owned by the given address
    /// @param owner - address to fetch number of NFTs for
    /// @return Returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex returns a tokenID at given index for owner
    /// @param owner - address to fetch the NFT TokenID for
    /// @param index - index of NFT in owned tokens array to fetch
    /// @return Returns the TokenID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract CryptoFrenchiesDAO is Ownable {

struct Proposal {
    uint256 nftTokenId;
    uint256 deadline;
    uint256 yayVotes;
    uint256 nayVotes;
    bool executed;
    mapping(uint256 => bool) voters;
  }

  // Create a mapping of ID to Proposal
  mapping(uint256 => Proposal) public proposals;
  // Number of proposals that have been created
  uint256 public numProposals;

  IFakeNFTMarketplace nftMarketplace;
  ICryptoFrenchiesNFT cryptoFrenchiesNFT;

  constructor(address _nftMarketplace, address _cryptoFrenchiesNFT) payable {
    nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
    cryptoFrenchiesNFT = ICryptoFrenchiesNFT(_cryptoFrenchiesNFT);
  }

  // Create a modifier which only allows a function to be
  // called by someone who owns at least 1 CryptoFrenchiesNFT
  modifier nftHolderOnly() {
    require(cryptoFrenchiesNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
    _;
  }

  /// @dev createProposal allows a CryptoFrenchiesNFT holder to create a new proposal in the DAO
  /// @param _nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMarketplace if this proposal passes
  /// @return Returns the proposal index for the newly created proposal
  function createProposal(uint256 _nftTokenId)
    external
    nftHolderOnly
    returns (uint256)
  {
    require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
    Proposal storage proposal = proposals[numProposals];
    proposal.nftTokenId = _nftTokenId;
    // Set the proposal's voting deadline to be (current time + 5 minutes)
    proposal.deadline = block.timestamp + 5 minutes;

    numProposals++;

    return numProposals - 1;
  }

  // A modifier which only allows a function to be
  // called if the given proposal's deadline has not been exceeded yet
  modifier activeProposalOnly(uint256 proposalIndex) {
    require(
        proposals[proposalIndex].deadline > block.timestamp,
        "DEADLINE_EXCEEDED"
    );
    _;
  }

  // Create an enum named Vote containing possible options for a vote
  enum Vote {
      YAY,
      NAY
  }

    /// @param proposalIndex - the index of the proposal to vote on in the proposals array
    /// @param vote - the type of vote they want to cast
  function voteOnProposal(uint256 proposalIndex, Vote vote)
      external
      nftHolderOnly
      activeProposalOnly(proposalIndex)
  {
      Proposal storage proposal = proposals[proposalIndex];

      uint256 voterNFTBalance = cryptoFrenchiesNFT.balanceOf(msg.sender);
      uint256 numVotes = 0;

      // Calculate how many NFTs are owned by the voter
      // that haven't already been used for voting on this proposal
      for (uint256 i = 0; i < voterNFTBalance; i++) {
          uint256 tokenId = cryptoFrenchiesNFT.tokenOfOwnerByIndex(msg.sender, i);
          if (proposal.voters[tokenId] == false) {
              numVotes++;
              proposal.voters[tokenId] = true;
          }
      }
      require(numVotes > 0, "ALREADY_VOTED");

      if (vote == Vote.YAY) {
          proposal.yayVotes += numVotes;
      } else {
          proposal.nayVotes += numVotes;
      }
  }

    // Create a modifier which only allows a function to be
  // called if the given proposals' deadline HAS been exceeded
  // and if the proposal has not yet been executed
  modifier inactiveProposalOnly(uint256 proposalIndex) {
      require(
          proposals[proposalIndex].deadline <= block.timestamp,
          "DEADLINE_NOT_EXCEEDED"
      );
      require(
          proposals[proposalIndex].executed == false,
          "PROPOSAL_ALREADY_EXECUTED"
      );
      _;
  }

  /// @param proposalIndex - the index of the proposal to execute in the proposals array
  function executeProposal(uint256 proposalIndex)
      external
      nftHolderOnly
      inactiveProposalOnly(proposalIndex)
  {
      Proposal storage proposal = proposals[proposalIndex];

      // If the proposal has more YAY votes than NAY votes
      // purchase the NFT from the FakeNFTMarketplace
      if (proposal.yayVotes > proposal.nayVotes) {
          uint256 nftPrice = nftMarketplace.getPrice();
          require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
          nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
      }
      proposal.executed = true;
  }

    /// @dev withdrawEther allows the contract owner (deployer) to withdraw the ETH from the contract
  function withdrawEther() external onlyOwner {
      payable(owner()).transfer(address(this).balance);
  }

    // The following two functions allow the contract to accept ETH deposits
  // directly from a wallet without calling a function
  receive() external payable {}

  fallback() external payable {}
}
