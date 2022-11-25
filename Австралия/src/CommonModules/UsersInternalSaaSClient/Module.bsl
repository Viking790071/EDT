#Region Internal

// Opens the service user password input form.
//
// Parameters:
//  ContinuationHandler - NotifyDescription to be processed after the password is entered.
//  OwnerForm - ClientApplicationForm that requests the password.
//  SaaSUserPassword - String - current SaaS user password.
//
Procedure RequestPasswordForAuthenticationInService(ContinuationHandler, OwnerForm, ServiceUserPassword) Export
	
	If ServiceUserPassword = Undefined Then
		OpenForm("CommonForm.AuthenticationInService", , OwnerForm, , , , ContinuationHandler);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, ServiceUserPassword);
	EndIf;
	
EndProcedure

#EndRegion
