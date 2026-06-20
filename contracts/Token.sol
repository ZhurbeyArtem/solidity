pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  mapping(address => mapping(address => uint256)) private _allowances;

  // Holder list stored as 0-based array, exposed via 1-based index per tests
  address[] private _holders;
  mapping(address => uint256) private _holderIndex; // 1-based; 0 = not a holder

  mapping(address => uint256) private _dividends;

  function _addHolder(address addr) private {
    if (_holderIndex[addr] == 0) {
      _holders.push(addr);
      _holderIndex[addr] = _holders.length; // 1-based
    }
  }

  function _removeHolder(address addr) private {
    uint256 idx = _holderIndex[addr];
    if (idx == 0) return;
    uint256 last = _holders.length;
    if (idx != last) {
      address tail = _holders[last - 1];
      _holders[idx - 1] = tail;
      _holderIndex[tail] = idx;
    }
    _holders.pop();
    _holderIndex[addr] = 0;
  }

  function _updateHolder(address addr) private {
    if (balanceOf[addr] > 0) {
      _addHolder(addr);
    } else {
      _removeHolder(addr);
    }
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[msg.sender] >= value, "insufficient balance");
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _updateHolder(msg.sender);
    if (value > 0) _addHolder(to);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(balanceOf[from] >= value, "insufficient balance");
    require(_allowances[from][msg.sender] >= value, "insufficient allowance");
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _updateHolder(from);
    if (value > 0) _addHolder(to);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "must send ETH");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _addHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "nothing to burn");
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) return address(0);
    return _holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "must send ETH");
    uint256 supply = totalSupply;
    for (uint256 i = 0; i < _holders.length; i++) {
      address holder = _holders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(supply);
      _dividends[holder] = _dividends[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _dividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _dividends[msg.sender];
    require(amount > 0, "nothing to withdraw");
    _dividends[msg.sender] = 0;
    dest.transfer(amount);
  }
}
