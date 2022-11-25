///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

Function DefineFormType(FormName) Export
	
	Return NativeLanguagesSupportServer.DefineFormType(FormName);
	
EndFunction

Function ConfigurationUsesOnlyOneLanguage(PresentationsInTabularSection) Export
	
	If Metadata.Languages.Count() = 1 Then
		Return True;
	EndIf;
	
	If PresentationsInTabularSection Then
		Return False;
	EndIf;
	
	If DriveServer.AdditionalLanguagesUsed() Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function ObjectDoesntContainTSPresentations(Ref) Export
	
	Return Ref.Metadata().TabularSections.Find("Presentations") = Undefined;
	
EndFunction

#EndRegion

