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
	
	Topic = Parameters.Topic;
	AddTemplateParametersFormItems(Parameters.Template);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	Result = New Map;
	
	For Each AttributeName In AttributesList Do
		Result.Insert(AttributeName.Value, ThisObject[AttributeName.Value])
	EndDo;
	
	Close(Result);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddTemplateParametersFormItems(Template)
	
	AttributesToAdd = New Array;
	If Template.TemplateByExternalDataProcessor Then
		
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Template.ExternalDataProcessor);
			TemplateParameters = ExternalObject.TemplateParameters();
			
			TemplateParametersTable = New ValueTable;
			TemplateParametersTable.Columns.Add("Name"                , New TypeDescription("String", , New StringQualifiers(50, AllowedLength.Variable)));
			TemplateParametersTable.Columns.Add("Type"                , New TypeDescription("TypeDescription"));
			TemplateParametersTable.Columns.Add("Presentation"      , New TypeDescription("String", , New StringQualifiers(150, AllowedLength.Variable)));
			
			For each TemplateParameter In TemplateParameters Do
				TypeDetails = TemplateParameter.TypeDetails.Types();
				If TypeDetails.Count() > 0 Then
					If TypeDetails[0] <> TypeOf(Topic) Then
						NewParameter = TemplateParametersTable.Add();
						NewParameter.Name = TemplateParameter.ParameterName;
						NewParameter.Presentation = TemplateParameter.ParameterPresentation;
						NewParameter.Type = TemplateParameter.TypeDetails;
						AttributesToAdd.Add(New FormAttribute(TemplateParameter.ParameterName, TemplateParameter.TypeDetails,, TemplateParameter.ParameterPresentation));
					EndIf;
					
				EndIf;
			EndDo;
		EndIf;
	Else
		Query = New Query;
		Query.Text = 
		"SELECT
		|	MessagesTemplatesParameters.Ref,
		|	MessagesTemplatesParameters.ParameterName AS Name,
		|	MessagesTemplatesParameters.ParameterType AS Type,
		|	MessagesTemplatesParameters.ParameterPresentation AS Presentation
		|FROM
		|	Catalog.MessageTemplates.Parameters AS MessagesTemplatesParameters
		|WHERE
		|	MessagesTemplatesParameters.Ref = &Ref";
		
		Query.SetParameter("Ref", Template);
		
		TemplateParametersTable = Query.Execute().Unload();
		
		For each Attribute In TemplateParametersTable Do
			TypeDetails = Attribute.Type.Get();
			AttributesToAdd.Add(New FormAttribute(Attribute.Name, TypeDetails,, Attribute.Presentation));
		EndDo;
	EndIf;
	
	ChangeAttributes(AttributesToAdd);
	
	For Each TemplateParameter In TemplateParametersTable Do
		Item = Items.Add(TemplateParameter.Name, Type("FormField"), Items.TemplateParameters);
		Item.Type                        = FormFieldType.InputField;
		Item.TitleLocation         = FormItemTitleLocation.Left;
		Item.Title                  = TemplateParameter.Presentation;
		Item.DataPath                = TemplateParameter.Name;
		Item.HorizontalStretch   = False;
		Item.Width = 50;
		AttributesList.Add(TemplateParameter.Name);
	EndDo;
	
	ThisObject.Height = 3 + TemplateParametersTable.Count() * 2;
	
EndProcedure

#EndRegion

