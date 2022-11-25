///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Input field OnOpen event handler of the form to open the attribute value input form in different languages.
//
// Parameters:
//  Form   - ClientApplicationForm - a form that contains multilanguage attributes.
//  Object  - FormDataCollection - an object on the form.
//  Item - FormField - a form item for which the input form will be opened in different languages.
//  StandardProcessing - Boolean - indicates a standard (system) event processing execution.
//
Procedure OnOpen(Form, Object, Item, StandardProcessing) Export
	
	StandardProcessing = False;
	DataPath = Form.MultilanguageAttributesParameters[Item.Name];
	AttributeName = StrReplace(DataPath, "Object.", "");
	
	ItemName = Item.Name;
	FormParameters = New Structure;
	FormParameters.Insert("Ref",          Object.Ref);
	FormParameters.Insert("AttributeName",    AttributeName);
	FormParameters.Insert("CurrentValue", Item.EditText);
	FormParameters.Insert("ReadOnly",  Item.ReadOnly);
	
	If Object.Property("Presentations") Then
		FormParameters.Insert("Presentations", Object.Presentations);
	Else
		Presentations = New Structure();
		
		Presentations.Insert(AttributeName, Object[AttributeName]);
		Presentations.Insert(AttributeName + "Language1", Object[AttributeName + "Language1"]);
		Presentations.Insert(AttributeName + "Language2", Object[AttributeName + "Language2"]);
		Presentations.Insert(AttributeName + "Language3", Object[AttributeName + "Language3"]);
		Presentations.Insert(AttributeName + "Language4", Object[AttributeName + "Language4"]);
		
		FormParameters.Insert("AttributesValues", Presentations);
		
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("Object", Object);
	AdditionalParameters.Insert("AttributeName", AttributeName);
	
	Notification = New NotifyDescription("AfterInputStringsInDifferentLanguages", NativeLanguagesSupportClient, AdditionalParameters);
	OpenForm("CommonForm.InputInMultipleLanguages", FormParameters,,,,, Notification);
	
EndProcedure

#EndRegion

#Region Private

Procedure AfterInputStringsInDifferentLanguages(Result, AdditionalParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	Form = AdditionalParameters.Form;
	Object = AdditionalParameters.Object;
	If Result.StorageInTabularSection Then
		
		For each Presentation In Result.ValuesInDifferentLanguages Do
			Filter = New Structure("LanguageCode", Presentation.LanguageCode);
			FoundRows = Object.Presentations.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				If IsBlankString(Presentation.AttributeValue) 
					AND StrCompare(Result.DefaultLanguage, Presentation.LanguageCode) <> 0 Then
						Object.Presentations.Delete(FoundRows[0]);
					Continue;
				EndIf;
				PresentationsRow = FoundRows[0];
			Else
				PresentationsRow = Object.Presentations.Add();
				PresentationsRow.LanguageCode = Presentation.LanguageCode;
			EndIf;
			PresentationsRow[AdditionalParameters.AttributeName] = Presentation.AttributeValue;
			
		EndDo;
		
	Else
		
		For each Presentation In Result.ValuesInDifferentLanguages Do
			Object[AdditionalParameters.AttributeName + Presentation.Suffix]= Presentation.AttributeValue;
		EndDo;
		
	EndIf;
	
	If Result.Property("StringInCurrentLanguage") Then
		
		Object[AdditionalParameters.AttributeName] = Result.StringInCurrentLanguage;
		Notify("InputInMultipleLanguages", Result.StringInCurrentLanguage);
		Form.Modified = True;
		
	EndIf;
		
EndProcedure

#EndRegion
