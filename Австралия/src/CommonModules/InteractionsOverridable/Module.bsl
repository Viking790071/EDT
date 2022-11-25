///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// It is called to get contacts (members) by the specified interaction subject.
// It is used if at least one interaction subject is determined in the configuration.
//
// Parameters:
//  ContactsTableName   - String - an interaction subject table name, where search is required.
//                                   For example, "Documents.CustomerOrder".
//  SearchQueryText - String - a query fragment for the search is specified to this parameter. When 
//                                   performing a query, a reference to an interaction subject is inserted in the &Subject query parameter.
//
Procedure OnSearchForContacts(Val ContactsTableName, SearchQueryText) Export
	
	
	
EndProcedure	

// Allows to override an attached file owner for writing.
// This can be required, for example, in case of bulk mail, when it makes sense to store all 
// attached files together and not to replicate them to all bulk emails.
//
// Parameters:
//  Email - DocumentRef.IncomingEmail, DocumentRef.OutgoungEmail - an email, whose attachments need 
//           to be received.
//  AttachedFiles - Structure - specify information on files attached to an email:
//    * FilesOwner                     - DefinedType.AttachedFile - an attached file owner.
//    * AttachedFilesCatalogName - String - an attached file metadata object name.
//
Procedure OnReceiveAttachedFiles(Email, AttachedFiles) Export

EndProcedure

// It is called to set logic of interaction access restriction.
// For the example of filling access value sets, see comments to AccessManagement.
// FillAccessValuesSets.
//
// Parameters:
//  Object - DocumentObject.Meeting,
//           DocumentObject.PlannedInteraction,
//           DocumentObject.SMSMessage,
//           DocumentObject.PhoneCall,
//           DocumentObject.IncomingEmail,
//           DocumentObject.OutgoingEmail - an object for which the sets are populated.
//  
//  Table - ValueTable - returned by AccessManagement.AccessValuesSetsTable.
//
Procedure OnFillingAccessValuesSets(Object, Table) Export
	
	
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use InteractionsOverridable.OnSearchForContacts.
// Returns a query text that filters interaction subject contacts (members).
// It is used if at least one interaction subject is determined in the configuration.
//
// Parameters:
//  DeletePutInTempTable - Boolean - always False.
//  TableName                        - String - an interaction subject table name, where search will be performed.
//  DeleteMerge - Boolean - always True.
//
// Returns:
//  String - a query text.
//
Function QueryTextContactsSearchBySubject(DeletePutInTempTable, TableName, DeleteMerge = False) Export
	
	Return "";
	
EndFunction

// Obsolete. Use InteractionsOverridable.OnGetAttachedFiles.
// The ability to override an attached file owner for writing.
// This can be required, for example, in case of bulk mail. Here it makes sense to store all 
// attached files together and not to replicate them to all bulk emails.
//
// Parameters:
//  Email  - DocumentRef, DocumentObject - an email document, whose attachments need to be received.
//
// Returns:
//  Structure, Undefined  - undefined if all attached files are stored at the email.
//                             Structure if all files are stored in other object:
//                              * Owner - DefinedType.AttachedFile - an attached file owner.
//                              * CatalogNameAttachedFiles - String - an attached file metadata object name.
//
Function AttachedEmailFilesMetadataObjectData(Email) Export
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndRegion
