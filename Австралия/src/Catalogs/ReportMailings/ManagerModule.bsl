///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Reports.*");
	Result.Add("ReportFormats.*");
	Result.Add("Recipients.*");
	
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	IsAuthorizedUser(Author)
	|	OR Personal = FALSE
	|	OR IsFolder = TRUE";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = False;
	
EndProcedure

// Called upon initial filling of the PerformersRoles catalog.
//
// Parameters:
//  LanguagesCodes - Array - a list of configuration languages. Applicable to multilanguage configurations.
//  Items   - ValueTable - the filling data. Columns match the set of the PerformersRoles catalog 
//                                 attributes.
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items) Export
	
	Item = Items.Add();
	Item.PredefinedDataName = "PersonalMailings";
	Item.Description              = NStr("ru = 'Личные рассылки'; en = 'Personal mailings'; pl = 'Mailingi osobiste';es_ES = 'Envíos personales';es_CO = 'Envíos personales';tr = 'Kişisel gönderimler';it = 'Spedizioni personali';de = 'Persönliche Mailings'", CommonClientServer.DefaultLanguageCode());
	
EndProcedure

// PerformersRoles is called upon initial filling of a performer role being created.
//
// Parameters:
//  Object                  - CatalogObject.PerformersRoles - an object to be filled in.
//  Data                  - ValueTableRow - the filling data.
//  AdditionalParameters - Structure - additional parameters.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
EndProcedure

#EndRegion

#EndIf

