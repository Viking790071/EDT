#Region Private

// Checks that the infobase object is used as the authorization object of any external user except 
// the specified external user (if it is specified).
//
Function AuthorizationObjectIsInUse(Val AuthorizationObjectRef,
                                      Val CurrentExternalUserRef,
                                      FoundExternalUser = Undefined,
                                      CanAddExternalUser = False,
                                      ErrorText = "") Export
	
	Return UsersInternal.AuthorizationObjectIsInUse(
				AuthorizationObjectRef,
				CurrentExternalUserRef,
				FoundExternalUser,
				CanAddExternalUser,
				ErrorText);
	
EndFunction

#EndRegion
