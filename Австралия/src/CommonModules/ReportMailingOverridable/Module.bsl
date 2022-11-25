///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Allows you to change default formats and set pictures.
// To change the format parameters, see the  ReportsMailing.SetFormatParameters auxiliary method.
// Other examples of usage see the ReportsMailingCached.FormatsList function.
//
// Parameters:
//   FormatsList - ListOfValues - a list of formats.
//       * Value      - EnumRef.ReportStorageFormats - a format reference.
//       * Presentation - String - a format presentation.
//       * CheckMark       - Boolean - flag showing that the format is used by default.
//       * Picture      - Picture - a picture of the format.
//
// Example:
//	ReportsMailing.SetFormatParameters(FormatsList, HTML4, , False).
//	ReportsMailing.SetFormatParameters(FormatsList, XLS, , True).
//
Procedure OverrideFormatsParameters(FormatsList) Export
	
	// _Demo example beginning
	
	
	// _Demo example end
	
EndProcedure

// Allows you to add the details of cross-object links of types for mailing recipients.
// To register type parameters, see ReportsMailing.AddItemToRecipientTypesTable. 
// Other examples of usage see the ReportsMailingCached.RecipientTypesTable.
// Important:
//   Use this mechanism only if:
//   1. It is required to describe and present several types as one (as in the Users and UserGroups 
//   catalog).
//   2. It is required to change the type representation without changing the metadata synonym.
//   3. It is required to specify the type of email contact information by default.
//   4. It is required to define a group of contact information.
//
// Parameters:
//   TypesTable  - ValueTable - type details table.
//   AvailableTypes - Array - available types.
//
// Example:
//	Settings = New Structure;
//	Settings.Insert(MainType, Type(CatalogRef.Counterparties)).
//	Settings.Insert(CIKind, ContactsManager.ContactInformationKindByName(CounterpartyEmail));
//	ReportsMailing.AddItemToRecipientsTypesTable(TypesTable, AvailableTypes, Settings).
//
Procedure OverrideRecipientsTypesTable(TypesTable, AvailableTypes) Export
	
EndProcedure


// Allows you to define a handler for saving a spreadsheet document to a format.
// Important:
//   If non-standard processing is used (StandardProcessing is changed to False), then FullFileName 
//   must contain the full file name with extension.
//
// Parameters:
//   StandardProcessing - Boolean - a flag of standard subsystem mechanisms usage for saving to a format.
//   SpreadsheetDocument    - SpreadsheetDocument - a spreadsheet document to be saved.
//   Format               - EnumRef.ReportSaveFormats - a format for saving the spreadsheet document.
//                                                                        
//   FullFileName       - String - a full file name.
//       Passed without an extension if the format was added in the applied configuration.
//
// Example:
//	If Format = Enumeration.ReportSaveFormats.HTML4 Then
//		StandardProcessing = False.
//		FullFileName = FullFileName +.html.
//		SpreadsheetDocument.Write(FullFileName, SpreadsheetDocumentFileType.HTML4).
//	EndIf.
//
Procedure BeforeSaveSpreadsheetDocumentToFormat(StandardProcessing, SpreadsheetDocument, Format, FullFileName) Export
	
	// _Demo example beginning
	
	// _Demo example end
	
EndProcedure

// Allows you to define a handler for generating the recipients list.
//
// Parameters:
//   RecipientsParameters - Structure - mailing recipients generating parameters.
//   Query - Query - a query that will be used if the value of the StandardProcessing parameter remains True.
//   StandardProcessing - Boolean - a flag of standard mechanisms usage.
//   Result - Map - recipients and their email addresses.
//       * Key     - CatalogRef - a recipient.
//       * Value - String - a set of email addresses in the row with separators.
// 
Procedure BeforeGenerateMailingRecipientsList(RecipientsParameters, Query, StandardProcessing, Result) Export
	
EndProcedure

// Allows you to exclude reports that are not ready for integration with mailing.
//   Specified reports are used as a filter when selecting reports.
//
// Parameters:
//   ReportsToBeExcluded - Array - a list of reports in the form of objects with the Report type of 
//                       the MetadataObject connected to the ReportsOptions storage but not supporting integration with mailings.
//
Procedure DetermineReportsToExclude(ReportsToExclude) Export
	
	// _Demo example beginning
	
	//ReportsToExclude.Add(Metadata.Reports.PollStatistics);
	
	// _Demo example end
	
EndProcedure

#EndRegion
