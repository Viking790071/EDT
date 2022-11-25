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
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

#EndRegion

#EndRegion

#EndIf


#Region EventHandlers

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing, Metadata.ChartsOfCharacteristicTypes.TaskAddressingObjects);
	
EndProcedure

#EndIf

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Defines the settings of items initial filling.
//
// Parameters:
//  Settings - Structure - filling settings
//   * OnItemInitialFilling - Boolean - if True, then the OnItemInitialFilling individual filling 
//      procedure will be called for each item.
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = True;
	
EndProcedure

// Called upon initial filling of the task addressing objects.
// Standard ValueType attribute is filled in the OnItemInitialFilling procedure.
//
// Parameters:
//  LanguageCodes - Array - a list of configuration languages. Applicable to multilanguage configurations.
//  Items   - ValueTable - filling data. Column composition matches the attribute set of CCT object TaskAddressingObjects.
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items) Export
	
	Item = Items.Add();
	Item.PredefinedDataName = "AllAddressingObjects";
	NativeLanguagesSupportServer.FillMultilanguageAttribute(Item,
		"Description",
		"en = 'All objects addressing'; ru = 'Все объекты адресации';pl = 'Wszystkie obiekty adresowania';es_ES = 'Todos los objetos de direccionamiento';es_CO = 'Todos los objetos de direccionamiento';tr = 'Tüm nesneleri adresleme';it = 'Tutti gli oggetti indirizzati';de = 'Adressierung aller Objekte'",
		LanguagesCodes); // @NStr
	
	BusinessProcessesAndTasksOverridable.OnInitialFillingTasksAddressingObjects(LanguagesCodes, Items);
	
EndProcedure

// Called upon initial filling of new task addressing object.
//
// Parameters:
//  Object                   - ChartOfCharacteristicTypesObject.ImplementersRoles - the object to be filled in.
//  Data                  - ValuesTableRow - filling data.
//  AdditionalParameters - Structure - Additional parameters.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
	BusinessProcessesAndTasksOverridable.OnInitialFillingTaskAddressingObjectItem(Object, Data, AdditionalParameters);
	
EndProcedure

#EndRegion

#EndIf
