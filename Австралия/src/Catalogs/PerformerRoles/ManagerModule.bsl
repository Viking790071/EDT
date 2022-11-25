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
	
	Result.Add("BriefPresentation");
	Result.Add("Comment");
	Result.Add("ExternalRole");
	Result.Add("ExchangeNode");
	
	Return Result
EndFunction

// End StandardSubsystems.BatchObjectsModification

// Filling predefined items.

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If UsersClientServer.IsExternalUserSession() Then
		CurrentUser = ExternalUsers.CurrentExternalUser();
		AuthorizationObject = Catalogs[CurrentUser.AuthorizationObject.Metadata().Name].EmptyRef();
	Else
		AuthorizationObject = Catalogs.Users.EmptyRef();
	EndIf;
	
	SearchTextForAdditionalLanguages = "";
	If NativeLanguagesSupportServer.FirstAdditionalLanguageUsed() Then
		SearchTextForAdditionalLanguages  = " OR PerformerRoles.DescriptionLanguage1 LIKE &SearchString";
	EndIf;
	
	If NativeLanguagesSupportServer.FirstAdditionalLanguageUsed() Then
		SearchTextForAdditionalLanguages  = SearchTextForAdditionalLanguages 
			+ " OR PerformerRoles.DescriptionLanguage2 LIKE &SearchString";
	EndIf;
	
	If NativeLanguagesSupportServer.SecondAdditionalLanguageUsed() Then
		LanguageSuffix = NativeLanguagesSupportServer.CurrentLanguageSuffix();
	EndIf;
	
	QueryText = "SELECT ALLOWED TOP 20
		|	PerformerRoles.Ref AS Ref
		|FROM
		|	Catalog.PerformerRoles.Purpose AS AssigneeRolesAssignment
		|		LEFT JOIN Catalog.PerformerRoles AS PerformerRoles
		|		ON AssigneeRolesAssignment.Ref = PerformerRoles.Ref
		|WHERE
		|	AssigneeRolesAssignment.UsersType = &Type
		|	AND (PerformerRoles.Description LIKE &SearchString " + SearchTextForAdditionalLanguages + "
		|			OR PerformerRoles.Code LIKE &SearchString)
		|	AND NOT PerformerRoles.Ref IS NULL";
	
	Query = New Query(QueryText);
	
	Query.SetParameter("Type",          AuthorizationObject);
	Query.SetParameter("SearchString", "%" + Parameters.SearchString + "%");
	QueryResult = Query.Execute().Select();
	
	ChoiceData = New ValueList;
	While QueryResult.Next() Do
		ChoiceData.Add(QueryResult.Ref, QueryResult.Ref);
	EndDo;
	
EndProcedure

#EndIf

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = True;
	
EndProcedure

// Called upon initial filling of the ImplementersRoles catalog.
//
// Parameters:
//  LanguageCodes - Array - a list of configuration languages. Applicable to multilanguage configurations.
//  Items   - ValueTable - filling data. Column content matches the attribute set of the 
//                                 ImplementersRoles catalog.
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items) Export
	
	Item = Items.Add();
	Item.PredefinedDataName = "EmployeeResponsibleForTasksManagement";
	NativeLanguagesSupportServer.FillMultilanguageAttribute(Item,
		"Description",
		"en = 'Coordinator execution tasks'; ru = 'Координатор выполнения задач';pl = 'Koordynator wykonania zadań';es_ES = 'Tareas de ejecución del coordinador';es_CO = 'Tareas de ejecución del coordinador';tr = 'Koordinator yürütme görevleri';it = 'Compiti di esecuzione del coordinatore';de = 'Koordinator von Aufgaben für Ausführung'",
		LanguagesCodes); // @NStr
	
	Item.UsedWithoutAddressingObjects = True;
	Item.UsedByAddressingObjects  = True;
	Item.ExternalRole                      = False;
	Item.Code                              = "000000001";
	Item.BriefPresentation             = NStr("ru = '000000001'; en = '000000001'; pl = '000000001';es_ES = '000000001';es_CO = '000000001';tr = '000000001';it = '000000001';de = '000000001'");
	Item.MainAddressingObjectTypes = ChartsOfCharacteristicTypes.TaskAddressingObjects.AllAddressingObjects;
	
	BusinessProcessesAndTasksOverridable.OnInitiallyFillPerformersRoles(LanguagesCodes, Items);
	
EndProcedure

// ImplementersRoles is called upon initial filling of the implementer's role.
//
// Parameters:
//  Object                   - CatalogObject.ImplementersRoles - the object to be filled in.
//  Data                  - ValuesTableRow - filling data.
//  AdditionalParameters - Structure - Additional parameters.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
	BusinessProcessesAndTasksOverridable.AtInitialPerformerRoleFilling(Object, Data, AdditionalParameters);
	
EndProcedure

#EndRegion

#EndIf
