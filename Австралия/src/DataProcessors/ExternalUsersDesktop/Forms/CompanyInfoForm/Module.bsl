
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExtUser = SessionParameters.CurrentExternalUser;
	User	= UserName();
	
	If ValueIsFilled(ExtUser) Then
		
		AuthorizationObject = Common.ObjectAttributeValue(ExtUser, "AuthorizationObject");
		
		If TypeOf(AuthorizationObject) = Type("CatalogRef.Counterparties") Then
			Counterparty = AuthorizationObject;
		ElsIf TypeOf(AuthorizationObject) = Type("CatalogRef.ContactPersons") Then
			Counterparty = Common.ObjectAttributeValue(AuthorizationObject, "Owner");
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion