///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

// Recipients types table broken down by storage and user presentation of these types.
//
// Returns:
//   TypesTable - ValueTable - a recipients types table.
//       * FoundMetadataObjectID - CatalogRef.MetadataObjectIDs -  a reference that is stored in the 
//                                                                                              database.
//       * RecipientsType - TypeDescription - type by which the recipient and exclusion list values are limited.
//       * Presentation - String - a type presentation for users.
//       * CIMainKind - CatalogRef.ContactInformationKinds - contact information kind: email, by 
//                                                                       default.
//       * CIGroup - CatalogRef.ContactInformationKinds - contact information kind group.
//       * ChoiceFormPath - String - a path to the choice form.
//
Function RecipientsTypesTable() Export
	
	TypesTable = New ValueTable;
	TypesTable.Columns.Add("MetadataObjectID", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	TypesTable.Columns.Add("RecipientsType", New TypeDescription("TypeDescription"));
	TypesTable.Columns.Add("Presentation", New TypeDescription("String"));
	TypesTable.Columns.Add("MainCIKind", New TypeDescription("CatalogRef.ContactInformationKinds"));
	TypesTable.Columns.Add("CIGroup", New TypeDescription("CatalogRef.ContactInformationKinds"));
	TypesTable.Columns.Add("ChoiceFormPath", New TypeDescription("String"));
	TypesTable.Columns.Add("MainType", New TypeDescription("TypeDescription"));
	
	TypesTable.Indexes.Add("MetadataObjectID");
	TypesTable.Indexes.Add("RecipientsType");
	
	AvailableTypes = Metadata.Catalogs.ReportMailings.TabularSections.Recipients.Attributes.Recipient.Type.Types();
	
	// The Users catalog parameters + User groups.
	TypesSettings = New Structure;
	TypesSettings.Insert("MainType",       Type("CatalogRef.Users"));
	TypesSettings.Insert("AdditionalType", Type("CatalogRef.UserGroups"));
	ReportMailing.AddItemToRecipientsTypesTable(TypesTable, AvailableTypes, TypesSettings);
	
	//  Extension mechanism
	ReportMailingOverridable.OverrideRecipientsTypesTable(TypesTable, AvailableTypes);
	
	// Other catalogs parameters.
	BlankArray = New Array;
	For Each UnusedType In AvailableTypes Do
		ReportMailing.AddItemToRecipientsTypesTable(TypesTable, BlankArray, New Structure("MainType", UnusedType));
	EndDo;
	
	Return TypesTable;
EndFunction

// Reports to be excluded are used as a filter when selecting reports.
Function ReportsToExclude() Export
	MetadataArray = New Array;
	ReportMailingOverridable.DetermineReportsToExclude(MetadataArray);
	
	Result = New Array;
	For Each ReportMetadata In MetadataArray Do
		Result.Add(Common.MetadataObjectID(ReportMetadata));
	EndDo;
	
	ReportsToExclude = New FixedArray(Result);
	
	Return ReportsToExclude;
EndFunction

#EndRegion
