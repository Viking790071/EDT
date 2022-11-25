///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// The function is called when receiving an object presentation or a reference presentation 
// depending on the language that is used when the user is working.
//
// Parameters:
//  Data               - Structure - contains the values of the fields from which presentation is being generated.
//  Presentation        - String - a generated presentation must be put in this parameter.
//  StandardProcessing - Boolean - a flag indicating whether the standard presentation is generated is passed to this parameter.
//  AttributeName         - String - indicates which attribute stores the presentation in the main language.
//
Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing, AttributeName = "Description") Export
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		
		If NativeLanguagesSupportServer.IsMainLanguage()
			Or Not DriveServer.AdditionalLanguagesUsed() Then
			Return;
		EndIf;
		
		If NationalLanguageSupportCached.ObjectDoesntContainTSPresentations(Data.Ref) Then
			
			LanguageSuffix = NativeLanguagesSupportServer.CurrentLanguageSuffix();
			If ValueIsFilled(LanguageSuffix) Then
				
				StandardProcessing = False;
				If Data.Property(AttributeName + LanguageSuffix) Then
					Presentation = Data[AttributeName + LanguageSuffix];
				EndIf;
				
			EndIf;
			
			If Not ValueIsFilled(Presentation) Then
				Presentation = Data[AttributeName];
			EndIf;
			
		ElsIf Data.Property("Ref") Or Data.Ref <> Undefined Then
			QueryText = 
			"SELECT TOP 1
			|	Presentations.%2 AS Description
			|FROM
			|	%1.Presentations AS Presentations
			|WHERE
			|	Presentations.LanguageCode = &Language
			|	AND Presentations.Ref = &Ref";
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText,
			Data.Ref.Metadata().FullName(), AttributeName);
			
			Query = New Query(QueryText);
			
			Query.SetParameter("Ref", Data.Ref);
			Query.SetParameter("Language",   CurrentLanguage().LanguageCode);
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				StandardProcessing = False;
				Presentation = QueryResult.Unload()[0].Description;
			EndIf;
			
		EndIf;
		
	#EndIf
	
EndProcedure

// Called to generate fields used to generate a presentation of an object or a reference.
// The fields are generated considering the current user language.
//
// Parameters:
//  Fields                 - Array - an array that contains names of fields that are required to 
//                                  generate a presentation of an object or a reference.
//  StandardProcessing - Boolean - a flag indicating whether the standard (system) event processing is executed is passed to this parameter.
//                                  If this parameter is set to False in the handler procedure, 
//                                  standard event processing is skipped.
//  AttributeName         - String - indicates which attribute stores the presentation in the main language.
//
Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing, AttributeName = "Description") Export
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		
		If NativeLanguagesSupportServer.IsMainLanguage()
			Or Not DriveServer.AdditionalLanguagesUsed() Then
			Return;
		EndIf;
		
		StandardProcessing = False;
		Fields.Add(AttributeName);
		Fields.Add("Ref");
		
		If NativeLanguagesSupportServer.FirstAdditionalLanguageUsed() Then
			Fields.Add(AttributeName + "Language1");
		EndIf;
		
		If NativeLanguagesSupportServer.SecondAdditionalLanguageUsed() Then
			Fields.Add(AttributeName +"Language2");
		EndIf;
		
		If NativeLanguagesSupportServer.ThirdAdditionalLanguageUsed() Then
			Fields.Add(AttributeName +"Language3");
		EndIf;
		
		If NativeLanguagesSupportServer.FourthAdditionalLanguageUsed() Then
			Fields.Add(AttributeName +"Language4");
		EndIf;
	
	#EndIf
	
EndProcedure

// Returns the code of the default configuration language, for example, "en".
//
// Returns:
//  String - language code.
//
Function DefaultLanguageCode() Export
	#If NOT ThinClient AND NOT WebClient AND NOT MobileClient Then
		
		DefaultLanguageCode = Constants.DefaultLanguage.Get();
		If IsBlankString(DefaultLanguageCode) Then
			DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
		EndIf;
		
		Return DefaultLanguageCode;
		
	#Else
		Return StandardSubsystemsClient.ClientParameter("DefaultLanguageCode");
	#EndIf
EndFunction

#EndRegion