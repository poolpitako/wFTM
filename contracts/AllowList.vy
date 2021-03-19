# @version 0.2.8
# Copy/paste from https://github.com/banteg/guest-list

bouncers: public(HashMap[address, bool])
guests: public(HashMap[address, bool])

event GuestInvited:
    guest: address

event BouncerAdded:
    bouncer: address

@external
def __init__():
    self.bouncers[msg.sender] = True
    log BouncerAdded(msg.sender)


@external
def invite_guest(guest: address):
    assert self.bouncers[msg.sender]  # dev: unauthorized
    assert not self.guests[guest]  # dev: already invited
    self.guests[guest] = True
    log GuestInvited(guest)


@external
def add_bouncer(bouncer: address):
    assert self.bouncers[msg.sender]  # dev: unauthorized
    assert not self.bouncers[bouncer]  # dev: already a bouncer
    self.bouncers[bouncer] = True
    log BouncerAdded(bouncer)

@view
@external
def authorized(guest: address, amount: uint256) -> bool:
    return self.guests[guest]
