#Region Public

// Returns the current user or the current external user, depending on which one has signed in.
// 
//  It is recommended that you use the function in a script fragment that supports both sign in options.
//
// Returns:
//  CatalogRef.Users, CatalogRef.ExternalUsers - a user or an external user.
//    
//
Function AuthorizedUser() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return UsersInternal.AuthorizedUser();
#Else
	Return StandardSubsystemsClient.ClientParameter("AuthorizedUser");
#EndIf
	
EndFunction

// Returns the current user.
//  It is recommended that you use the function in a script fragment that does not support external users.
//
//  If the current user is external, throws an exception.
//
// Returns:
//  CatalogRef.Users - a user.
//
Function CurrentUser() Export
	
	AuthorizedUser = AuthorizedUser();
	
	Return AuthorizedUser;
	
EndFunction

// Returns the current external user.
//  It is recommended that you use the function in a script fragment that supports external users only.
//
//  If the current user is not external, throws an exception.
//
// Returns:
//  CatalogRef.ExternalUsers - an external user.
//
Function CurrentExternalUser() Export
	
	AuthorizedUser = AuthorizedUser();
	
	If TypeOf(AuthorizedUser) <> Type("CatalogRef.ExternalUsers") Then
		Raise
			NStr("ru = 'Невозможно получить текущего внешнего пользователя
					|в сеансе пользователя.'; 
					|en = 'Cannot get the current external user
					|in the user session.'; 
					|pl = 'Nie można uzyskać bieżącego użytkownika zewnętrznego 
					|w sesji użytkownika.';
					|es_ES = 'No se puede obtener el usuario externo actual
					|en la sesión del usuario.';
					|es_CO = 'No se puede obtener el usuario externo actual
					|en la sesión del usuario.';
					|tr = 'Geçerli harici kullanıcı, 
					| kullanıcı oturumunda alınamıyor.';
					|it = 'Impossibile recuperare l''utente esterno corrente
					|nella sessione dell''utente.';
					|de = 'Es ist nicht möglich, den aktuellen externen Benutzer
					|in einer Benutzersitzung zu erhalten.'");
	EndIf;
	
	Return AuthorizedUser;
	
EndFunction

// Returns True if the current user is external.
//
// Returns:
//  Boolean - True if the current user is external.
//
Function IsExternalUserSession() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return UsersInternalCached.IsExternalUserSession();
#Else
	Return StandardSubsystemsClient.ClientParameter("IsExternalUserSession");
#EndIf
	
EndFunction

#EndRegion
