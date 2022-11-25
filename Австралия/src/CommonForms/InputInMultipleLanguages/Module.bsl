///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MetadataObject = Parameters.Ref.Metadata();
	MultilanguageStringsInAttributes = NativeLanguagesSupportServer.MultilanguageStringsInAttributes(MetadataObject);
	Attribute = MetadataObject.Attributes.Find(Parameters.AttributeName);
	If Attribute = Undefined Then
		For each StandardAttribute In MetadataObject.StandardAttributes Do
			If StrCompare(StandardAttribute.Name, Parameters.AttributeName) = 0 Then
				Attribute = StandardAttribute;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	MainLanguageSuffix         = "";
	AdditionalLanguage1Suffix = "Language1";
	AdditionalLanguage2Suffix = "Language2";
	AdditionalLanguage3Suffix = "Language3";
	AdditionalLanguage4Suffix = "Language4";
	
	If StrCompare(Constants.DefaultLanguage.Get(), CurrentLanguage().LanguageCode) <> 0 Then
		MainLanguageSuffix = NativeLanguagesSupportServer.CurrentLanguageSuffix();
		If MainLanguageSuffix = "Language1" Then
			AdditionalLanguage1Suffix  = "";
		ElsIf MainLanguageSuffix = "Language2" Then
			AdditionalLanguage2Suffix = "";
		ElsIf MainLanguageSuffix = "Language3" Then
			AdditionalLanguage3Suffix = "";
		ElsIf MainLanguageSuffix = "Language4" Then
			AdditionalLanguage4Suffix = "";
		EndIf;
		
	EndIf;
	
	LanguagesSet = New ValueTable;
	LanguagesSet.Columns.Add("LanguageCode",      Common.StringTypeDetails(10));
	LanguagesSet.Columns.Add("Presentation", Common.StringTypeDetails(150));
	LanguagesSet.Columns.Add("Suffix",       Common.StringTypeDetails(50));
	
	If MultilanguageStringsInAttributes Then
		
		LanguagesPresentations = New Map;
		For Each ConfigurationLanguage In Metadata.Languages Do
			LanguagesPresentations.Insert(ConfigurationLanguage.LanguageCode, ConfigurationLanguage.Presentation());
		EndDo;
		
		NewLanguage = LanguagesSet.Add();
		NewLanguage.LanguageCode = Constants.DefaultLanguage.Get();
		NewLanguage.Presentation = LanguagesPresentations[NewLanguage.LanguageCode];
		NewLanguage.Suffix = MainLanguageSuffix;
		
		If NativeLanguagesSupportServer.FirstAdditionalLanguageUsed() Then
			NewLanguage = LanguagesSet.Add();
			NewLanguage.LanguageCode = NativeLanguagesSupportServer.FirstAdditionalInfobaseLanguageCode();
			NewLanguage.Presentation = LanguagesPresentations[NewLanguage.LanguageCode];
			NewLanguage.Suffix = AdditionalLanguage1Suffix;
		EndIf;
		
		If NativeLanguagesSupportServer.SecondAdditionalLanguageUsed() Then
			NewLanguage = LanguagesSet.Add();
			NewLanguage.LanguageCode = NativeLanguagesSupportServer.SecondAdditionalInfobaseLanguageCode();
			NewLanguage.Presentation = LanguagesPresentations[NewLanguage.LanguageCode];
			NewLanguage.Suffix = AdditionalLanguage2Suffix;
		EndIf;
		
		If NativeLanguagesSupportServer.ThirdAdditionalLanguageUsed() Then
			NewLanguage = LanguagesSet.Add();
			NewLanguage.LanguageCode = NativeLanguagesSupportServer.ThirdAdditionalInfobaseLanguageCode();
			NewLanguage.Presentation = LanguagesPresentations[NewLanguage.LanguageCode];
			NewLanguage.Suffix = AdditionalLanguage3Suffix;
		EndIf;
		
		If NativeLanguagesSupportServer.FourthAdditionalLanguageUsed() Then
			NewLanguage = LanguagesSet.Add();
			NewLanguage.LanguageCode = NativeLanguagesSupportServer.FourthAdditionalInfobaseLanguageCode();
			NewLanguage.Presentation = LanguagesPresentations[NewLanguage.LanguageCode];
			NewLanguage.Suffix = AdditionalLanguage4Suffix;
		EndIf;
		
	Else
		
		For Each ConfigurationLanguage In Metadata.Languages Do
		
			NewLanguage = LanguagesSet.Add();
			NewLanguage.LanguageCode = ConfigurationLanguage.LanguageCode;
			NewLanguage.Presentation = ConfigurationLanguage.Presentation();
		
		EndDo;
		
	EndIf;
	
	If Attribute = Undefined Then
		ErrorTemplate = NStr("ru = 'При открытии формы InputInDifferentLanguages в параметре AttributeName указан не существующий реквизит %1'; en = 'Cannot open the InputInDifferentLanguages form. Attribute %1 specified in the AttributeName parameter does not exist.'; pl = 'Nie można otworzyć formularz InputInDifferentLanguages. Atrybut %1 określony w parametrze AttributeName parameter nie istnieje.';es_ES = 'No puede abrir el formulario InputInDifferentLanguages. El atributo %1especificado en el parámetro AttributeName no existe.';es_CO = 'No puede abrir el formulario InputInDifferentLanguages. El atributo %1especificado en el parámetro AttributeName no existe.';tr = 'InputInDifferentLanguages formu açılamıyor. AttributeName parametresinde belirtilen %1 yetkisi mevcut değil.';it = 'Impossibile aprire il modulo InputInDifferentLanguages. L''attributo %1 indicato nel parametro AttributeName non esiste.';de = 'Die InputInDifferentLanguages Form kann nicht geöffnet werden. Das Attribut %1 bezeichnet im AttributeName-Parameter existiert nicht.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, Parameters.AttributeName);
	EndIf;
	
	If Attribute.MultiLine Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "MultiLine");
	EndIf;
	
	For Each ConfigurationLanguage In LanguagesSet Do
		NewString = Languages.Add();
		FillPropertyValues(NewString, ConfigurationLanguage);
		NewString.Name = "_" + StrReplace(New UUID, "-", "");
	EndDo;
	
	GenerateInputFieldsInDifferentLanguages(Attribute.MultiLine, Parameters.ReadOnly);
	
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
	Else
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 на разных языках';
				|en = '%1 in different languages'; pl = '%1 w różnych językach';es_ES = '%1 en diferentes idiomas';es_CO = '%1 en diferentes idiomas';tr = 'Farklı dillerde %1';it = '%1 in diverse lingue';de = '%1 in verschiedenen Sprachen'"), Attribute.Presentation());
		If IsBlankString(Title) Then
			Title = Attribute.Presentation();
		EndIf;
	EndIf;
	
	DefaultLanguage = NationalLanguageSupportClientServer.DefaultLanguageCode();
	
	LanguageDetails = LanguageDetails(CurrentLanguage().LanguageCode);
	If LanguageDetails <> Undefined Then
		ThisObject[LanguageDetails.Name] = Parameters.CurrentValue;
	EndIf;
	
	If MultilanguageStringsInAttributes Then
		
		LanguageDetails = LanguageDetails(Constants.DefaultLanguage.Get());
		If IsBlankString(MainLanguageSuffix) Then
			ThisObject[LanguageDetails.Name] = Parameters.CurrentValue;
		Else
			ThisObject[LanguageDetails.Name] = Parameters.AttributesValues[Parameters.AttributeName + MainLanguageSuffix];
		EndIf;
		
		If NativeLanguagesSupportServer.FirstAdditionalLanguageUsed() Then
			LanguageDetails = LanguageDetails(Constants.AdditionalLanguage1.Get());
			If IsBlankString(AdditionalLanguage1Suffix) Then
				ThisObject[LanguageDetails.Name] = Parameters.CurrentValue;
			Else
				ThisObject[LanguageDetails.Name] = Parameters.AttributesValues[Parameters.AttributeName + AdditionalLanguage1Suffix];
			EndIf;
		EndIf;
		
		If NativeLanguagesSupportServer.SecondAdditionalLanguageUsed() Then
			LanguageDetails = LanguageDetails(Constants.AdditionalLanguage2.Get());
			If IsBlankString(AdditionalLanguage2Suffix) Then
				ThisObject[LanguageDetails.Name] = Parameters.CurrentValue;
			Else
				ThisObject[LanguageDetails.Name] = Parameters.AttributesValues[Parameters.AttributeName + AdditionalLanguage2Suffix];
			EndIf;
		EndIf;
		
		If NativeLanguagesSupportServer.ThirdAdditionalLanguageUsed() Then
			LanguageDetails = LanguageDetails(Constants.AdditionalLanguage3.Get());
			If IsBlankString(AdditionalLanguage3Suffix) Then
				ThisObject[LanguageDetails.Name] = Parameters.CurrentValue;
			Else
				ThisObject[LanguageDetails.Name] = Parameters.AttributesValues[Parameters.AttributeName + AdditionalLanguage3Suffix];
			EndIf;
		EndIf;
		
		If NativeLanguagesSupportServer.FourthAdditionalLanguageUsed() Then
			LanguageDetails = LanguageDetails(Constants.AdditionalLanguage4.Get());
			If IsBlankString(AdditionalLanguage4Suffix) Then
				ThisObject[LanguageDetails.Name] = Parameters.CurrentValue;
			Else
				ThisObject[LanguageDetails.Name] = Parameters.AttributesValues[Parameters.AttributeName + AdditionalLanguage4Suffix];
			EndIf;
		EndIf;
		
	Else
		
		For each Presentation In Parameters.Presentations Do
			
			LanguageDetails = LanguageDetails(Presentation.LanguageCode);
			If LanguageDetails <> Undefined Then
				If StrCompare(LanguageDetails.LanguageCode, CurrentLanguage().LanguageCode) = 0 Then
					ThisObject[LanguageDetails.Name] = ?(ValueIsFilled(Parameters.CurrentValue), Parameters.CurrentValue, Presentation[Parameters.AttributeName]);
				Else
					ThisObject[LanguageDetails.Name] = Presentation[Parameters.AttributeName];
				EndIf;
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	Result = New Structure("DefaultLanguage", DefaultLanguage);
	Result.Insert("ValuesInDifferentLanguages", New Array);
	Result.Insert("StorageInTabularSection", Not MultilanguageStringsInAttributes);
	
	For each Language In Languages Do
		
		If Language.LanguageCode = CurrentLanguage() Then
			Result.Insert("StringInCurrentLanguage", ThisObject[Language.Name]);
		EndIf;
		
		If CurrentLanguage() = DefaultLanguage AND Language.LanguageCode = DefaultLanguage Then
			Continue;
		EndIf;
		
		Values = New Structure;
		Values.Insert("LanguageCode",          Language.LanguageCode);
		Values.Insert("AttributeValue", ThisObject[Language.Name]);
		Values.Insert("Suffix",           Language.Suffix);
		
		Result.ValuesInDifferentLanguages.Add(Values);
	EndDo;
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GenerateInputFieldsInDifferentLanguages(MultilineMode, ReadOnly)
	
	Add = New Array;
	StringType = New TypeDescription("String");
	For Each ConfigurationLanguage In Languages Do
		Add.Add(New FormAttribute(ConfigurationLanguage.Name, StringType,, ConfigurationLanguage.Presentation));
	EndDo;
	
	ChangeAttributes(Add);
	ItemsParent = Items.LanguagesGroup;
	
	For Each ConfigurationLanguage In Languages Do
		
		If StrCompare(ConfigurationLanguage.LanguageCode, CurrentLanguage().LanguageCode) = 0 AND ItemsParent.ChildItems.Count() > 0 Then
			Item = Items.Insert(ConfigurationLanguage.Name, Type("FormField"), ItemsParent, ItemsParent.ChildItems.Get(0));
			CurrentItem = Item;
		Else
			Item = Items.Add(ConfigurationLanguage.Name, Type("FormField"), ItemsParent);
		EndIf;
		
		Item.DataPath        = ConfigurationLanguage.Name;
		Item.Type                = FormFieldType.InputField;
		Item.Width             = 40;
		Item.MultiLine = MultilineMode;
		Item.TitleLocation = FormItemTitleLocation.Top;
		Item.ReadOnly     = ReadOnly;
		
	EndDo;
	
EndProcedure

&AtServer
Function LanguageDetails(LanguageCode)
	
	Filter = New Structure("LanguageCode", LanguageCode);
	FoundItems = Languages.FindRows(Filter);
	If FoundItems.Count() > 0 Then
		Return FoundItems[0];
	EndIf;
	
	Return Undefined;
	
EndFunction


#EndRegion