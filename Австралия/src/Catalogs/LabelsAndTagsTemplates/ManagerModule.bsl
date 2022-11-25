#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.LabelsAndTagsTemplates);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region ProgramInterface

// Returns a name of an available data composition field.
//
Function GetFieldNameInTemplate(Val FieldName) Export
	
	FieldName = StrReplace(FieldName, ".DeletionMark", ".DeletionMark");
	FieldName = StrReplace(FieldName, ".Owner", ".Owner");
	FieldName = StrReplace(FieldName, ".Code", ".Code");
	FieldName = StrReplace(FieldName, ".Parent", ".Parent");
	FieldName = StrReplace(FieldName, ".Predefined", ".Predefined");
	FieldName = StrReplace(FieldName, ".IsFolder", ".IsFolder");
	FieldName = StrReplace(FieldName, ".Description", ".Description");
	Return FieldName;
	
EndFunction

#EndRegion

#EndIf