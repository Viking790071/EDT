///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use InteractionsClientServerOverridable.OnDeterminePossibleContacts.
// See the NewContactFormName property of the ContactsTypes parameter.
//
// It is called when creating a new contact.
// It is used if one or several contact types require to open another form instead the main one when 
// creating them.
// For example, it can be the form of a new catalog item creation wizard.
//
// Parameters:
//  ContactType   - String    - a contact catalog name.
//  FormParameter - Structure - a parameter that is passed when opening.
//
// Returns:
//  Boolean - False if a non-standard form is not opened, True otherwise.
//
// Example:
//	If ContactType = "Partners" Then
//		OpenForm("Catalog.Partners.Form.NewContactWizard", FormParameter);
//		Return True;
//	EndIf;
//	
//	Return False;
//
Function CreateContactNonstandardForm(ContactType, FormParameter)  Export
	
	Return False;
	
EndFunction

#EndRegion

#EndRegion
