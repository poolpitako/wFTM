# @version 0.2.8
# Copy/paste from https://github.com/banteg/guest-list

bouncers: public(HashMap[address, bool])
guests: public(HashMap[address, bool])


@external
def __init__():
    self.bouncers[msg.sender] = True


@external
def invite_guest(guest: address):
    assert self.bouncers[msg.sender]  # dev: unauthorized
    assert not self.guests[guest]  # dev: already invited
    self.guests[guest] = True


@external
def add_bouncer(bouncer: address):
    assert self.bouncers[msg.sender]  # dev: unauthorized
    assert not self.bouncers[bouncer]  # dev: already a bouncer
    self.bouncers[bouncer] = True

@view
@external
def authorized(guest: address, amount: uint256) -> bool:
    return self.guests[guest]
