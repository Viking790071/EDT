#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var IBUserProcessingParameters; // The parameters that are filled when processing an infobase user.
                                        // Used in OnWrite event handler.

Var IsNew; // Shows whether a new object was written.
                // Used in OnWrite event handler.

#EndRegion

// *Region Public.
//
// The object interface is implemented through AdditionalProperties:
//
// IBUserDetails - a structure with the following properties:
//   Action - String - "Write" or "Delete".
//      1. If Action = "Delete", no other properties are necessary. If search by the IBUserID 
//      attribute returns no results, the infobase user is considered to be deleted successfully.
//      
//      2. If Action = "Write", a new infobase user is created or the old infobase user is updated 
//      by the specified properties.
//
//   CanAuthorize - Undefined - calculate automatically:
//                            If user access to the infobase is denied, it remains denied. Otherwise 
//                            grant access based on the StandardAuthentication, OSAuthentication and 
//                            OpenIDAuthentication values (if all these values are set to False, access is denied).
//                          - Boolean - if True, setting the authentication based on the values of 
//                            the attributes.
//                            If False, denying user access to infobase.
//                          - Not specified - granting access based on the StandardAuthentication, 
//                            OSAuthentication, and OpenIDAuthentication values (to support backward compatibility).
//
//   StandardAuthentication, OSAuthentication, and OpenIDAuthentication - setting the authentication 
//      values based on the used property.
//      CanAuthorize - setting the authentication values to the current values.
// 
//   Other properties.
//      The content of other properties is specified similarly to the property content of the parameter.
//      The UpdatedProperties for the Users.WriteIBUser()  property is set by the Description, 
//      except for the FullName.
//
//      To map an independent infobase user to a user from a catalog that is not yet mapped to 
//      another infobase user, insert the property.
//      UUID. If you specify the ID of the infobase user that is mapped to the current user, nothing 
//      changes.
//
//   When running "Write" or "Delete", the InfobaseUserID attribute
//   updates automatically (no modification required).
//
//   After completing the action, the following structure properties are added or updated:
//   - ActionResult - String containing one of these values:
//       "IBUserAdded", "IBUserChanged", "IBUserDeleted",
//       "MappingToNonExistingIBUserCleared", or "IBUserDeletionNotRequired".
//   - UUID - an infobase user UUID.
//
// CreateAdministrator - String - must be filled in to call the OnCreateAdministrator event after 
//   the IBUserDetails is processed and the created or modified infobase user has administrator 
//   roles.
//   This provides for associated actions on creating an administrator. For example, add a new user 
//   to the Administrators access group.
//
// *EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("NewUserGroup")
		AND ValueIsFilled(AdditionalProperties.NewUserGroup) Then
		
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.UserGroups");
		Lock.Lock();
		
		GroupObject = AdditionalProperties.NewUserGroup.GetObject();
		GroupObject.Content.Add().User = Ref;
		GroupObject.Write();
	EndIf;
	
	// Updating the content of "All users" auto group.
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	UsersInternal.UpdateUserGroupComposition(
		Catalogs.UserGroups.AllUsers, Ref, ItemsToChange, ModifiedGroups);
	
	UsersInternal.UpdateUserGroupCompositionUsage(
		Ref, ItemsToChange, ModifiedGroups);
	
	UsersInternal.EndIBUserProcessing(
		ThisObject, IBUserProcessingParameters);
	
	UsersInternal.AfterUserGroupsUpdate(
		ItemsToChange, ModifiedGroups);
	
	UsersInternal.EnableUserActivityMonitoringJobIfRequired(Ref);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	IBUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
	ContactInformation.Clear();
	Comment = "";
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
Procedure CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange() Export
	
	// The infobase user must be deleted. Otherwise, they will be added to the IBUsers form error list, 
	// and any attempt to sign in as this user will result in error.
	
	IBUserDetails = New Structure;
	IBUserDetails.Insert("Action", "Delete");
	AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters, True);
	UsersInternal.EndIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
EndProcedure

#EndRegion

#EndIf
