

@wrapMethod(DoorControllerPS)
protected func ExposeQuickHakcsIfNotConnnectedToAP() -> Bool {
    let vanilla = wrappedMethod();
    if !vanilla {
        // force true if not already hackable
        return true;
    }
    return vanilla;
}

@wrapMethod(SharedGameplayPS)
public func IsConnectedToBackdoorDevice() -> Bool {
    let vanilla = wrappedMethod();
    if !vanilla {
        return true;
    }
    return vanilla;
}


@replaceMethod(SharedGameplayPS)
public const func HasNetworkBackdoor() -> Bool {
    return true;
}



