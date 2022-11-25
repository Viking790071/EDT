///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

Function OnDefineSettings() Export
	
	Settings = New Structure("TemplateSubjects, CommonAttributes");
	Settings.Insert("UseArbitraryParameters", False);
	Settings.Insert("DCSParametersValues", New Structure);
	Settings.Insert("EmailFormat", "");
	Settings.Insert("ExtendedRecipientsList", False);
	Settings.Insert("AlwaysShowTemplatesChoiceForm", True);
	
	CommonAttributesTree = MessageTemplatesInternal.DetermineCommonAttributes();
	Settings.CommonAttributes = MessageTemplatesInternal.CommonAttributes(CommonAttributesTree);
	Settings.TemplateSubjects = MessageTemplatesInternal.DefineTemplatesSubjects();
	
	MessageTemplatesOverridable.OnDefineSettings(Settings);
	Settings.CommonAttributes = CommonAttributesTree;
	
	For each TemplateSubject In Settings.TemplateSubjects Do
		For each DSCParameter In Settings.DCSParametersValues Do
			If NOT TemplateSubject.DCSParametersValues.Property(DSCParameter.Key)
				OR TemplateSubject.DCSParametersValues[DSCParameter.Key] = Null Then
					TemplateSubject.DCSParametersValues.Insert(DSCParameter.Key, Settings.DCSParametersValues[DSCParameter.Key]);
			EndIf;
		EndDo;
	EndDo;
	
	Settings.TemplateSubjects.Sort("Presentation");
	
	Result = New FixedStructure(Settings);
	Return Result;
	
EndFunction

#EndRegion
