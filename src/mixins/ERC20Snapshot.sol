// SPDX-License-Identifier: AGLP-v3
pragma solidity >=0.8.13;

import {ERC20} from "@omniprotocol/mixins/ERC20.sol";

contract ERC20Snapshot is ERC20 {
    uint64 public lastSnapshotAt;
    uint256 public currentSnapshot;
    event Snapshot(uint256 id);

    function incrementSnapshot() public virtual returns (uint256 currentId) {
        require(lastSnapshotAt + 30 minutes <= block.timestamp, "TEAPOT");
        lastSnapshotAt = uint64(block.timestamp);
        currentId = ++currentSnapshot;
        emit Snapshot(currentId);
    }

    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }

    mapping(address => Snapshots) private _balanceOfSnapshots;
    Snapshots private _totalSupplySnapshots;

    function _updateAccountSnapshot(address account) private {
        _updateSnapshot(_balanceOfSnapshots[account], balanceOf[account]);
    }

    function _updateTotalSupplySnapshot() private {
        _updateSnapshot(_totalSupplySnapshots, totalSupply);
    }

    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue)
        private
    {
        uint256 currentId = currentSnapshot;
        if (_last(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function _mint(address to, uint256 amount) internal virtual override {
        super._mint(to, amount);
        _updateAccountSnapshot(to);
        _updateTotalSupplySnapshot();
    }

    function _burn(address from, uint256 amount) internal virtual override {
        super._burn(from, amount);
        _updateAccountSnapshot(from);
        _updateTotalSupplySnapshot();
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool ok)
    {
        ok = super.transfer(to, amount);
        _updateAccountSnapshot(msg.sender);
        _updateAccountSnapshot(to);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool ok) {
        ok = super.transferFrom(from, to, amount);
        _updateAccountSnapshot(from);
        _updateAccountSnapshot(to);
    }

    function _valueAt(uint256 snapshotId, Snapshots storage snapshots)
        private
        view
        returns (bool, uint256)
    {
        require(
            0 < snapshotId && snapshotId <= currentSnapshot,
            "ERC20Snapshot: INVALID_SNAPSHOT"
        );

        uint256 index = _findIndex(snapshots.ids, snapshotId);

        if (index == snapshots.ids.length) {
            return (false, 0);
        } else {
            return (true, snapshots.values[index]);
        }
    }

    function _findIndex(uint256[] storage array, uint256 snapshotId)
        private
        view
        returns (uint256)
    {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = (low & high) + (low ^ high) / 2;

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > snapshotId) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == snapshotId) {
            return low - 1;
        } else {
            return low;
        }
    }

    function _last(uint256[] storage ns) private view returns (uint256) {
        return ns.length == 0 ? 0 : ns[ns.length - 1];
    }

    function balanceOfAt(address account, uint256 snapshotId)
        public
        view
        virtual
        returns (uint256)
    {
        (bool ok, uint256 value) = _valueAt(
            snapshotId,
            _balanceOfSnapshots[account]
        );
        return ok ? value : balanceOf[account];
    }

    function totalSupplyAt(uint256 snapshotId)
        public
        view
        virtual
        returns (uint256)
    {
        (bool ok, uint256 value) = _valueAt(snapshotId, _totalSupplySnapshots);
        return ok ? value : totalSupply;
    }
}
