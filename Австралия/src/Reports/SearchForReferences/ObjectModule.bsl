#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions
// The settings of the common report form of the "Reports options" subsystem.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//       Undefined when called without a context.
//   OptionKey - String, Undefined - a name of a predefined report option or a UUID of a 
//       user-defined report option.
//       Undefined when called without a context.
//   Settings - Structure - see the return value of
//       ReportsClientServer.GetDefaultReportSettings().
//
Procedure DefineFormSettings(Form, OptionKey, Settings) Export
	Settings.GenerateImmediately = True;
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	StandardProcessing = False;
	
	// Regenerating title by reference set.
	Settings = SettingsComposer.GetSettings();
	RefSet = Settings.DataParameters.FindParameterValue( New DataCompositionParameter("RefSet") );
	If RefSet <> Undefined Then
		RefSet = RefSet.Value;
	EndIf;
	Header = TitleByReferenceSet(RefSet);
	SettingsComposer.FixedSettings.OutputParameters.SetParameterValue("Title", Header);
	
	CompositionProcessor = CompositionProcessor(DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.Output(CompositionProcessor);
EndProcedure

#EndRegion

#Region Private

Function CompositionProcessor(DetailsData = Undefined, GeneratorType = "DataCompositionTemplateGenerator")
	
	Settings = SettingsComposer.GetSettings();
	
	// List of references from parameters.
	ParameterValue = Settings.DataParameters.FindParameterValue( New DataCompositionParameter("RefSet") ).Value;
	ValueType = TypeOf(ParameterValue);
	If ValueType = Type("ValueList") Then
		RefsArray = ParameterValue.UnloadValues();
	ElsIf ValueType = Type("Array") Then
		RefsArray = ParameterValue;
	Else
		RefsArray = New Array;
		If ParameterValue <>Undefined Then
			RefsArray.Add(ParameterValue);
		EndIf;
	EndIf;
	
	// Parameters of output from fixed parameters.
	For Each OutputParameter In SettingsComposer.FixedSettings.OutputParameters.Items Do
		If OutputParameter.Use Then
			Item = Settings.OutputParameters.FindParameterValue(OutputParameter.Parameter);
			If Item <> Undefined Then
				Item.Use = True;
				Item.Value      = OutputParameter.Value;
			EndIf;
		EndIf;
	EndDo;
	
	// Data source tables
	UsageInstances = Common.UsageInstances(RefsArray);
	
	// Checking whether there are all references.
	For Each Ref In RefsArray Do
		If UsageInstances.Find(Ref, "Ref") = Undefined Then
			AdditionalInformation = UsageInstances.Add();
			AdditionalInformation.Ref = Ref;
			AdditionalInformation.AuxiliaryData = True;
		EndIf;
	EndDo;
		
	ExternalData = New Structure;
	ExternalData.Insert("UsageInstances", UsageInstances);
	
	// Perform
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData, , Type(GeneratorType));
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(Template, ExternalData, DetailsData);
	
	Return CompositionProcessor;
EndFunction

Function TitleByReferenceSet(Val RefSet)

	If TypeOf(RefSet) = Type("ValueList") Then
		TotalRefs = RefSet.Count();
		If TotalRefs = 1 Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Места использования %1'; en = 'Usage instances %1'; pl = 'Miejsca użycia %1';es_ES = 'Ubicaciones de uso %1';es_CO = 'Ubicaciones de uso %1';tr = 'Kullanım yerleri %1';it = 'Istanze di uso %1';de = 'Verwendungsorte %1'"), Common.SubjectString(RefSet[0].Value));
		ElsIf TotalRefs > 1 Then
		
			EqualType = True;
			FirstRefType = TypeOf(RefSet[0].Value);
			For Position = 0 To TotalRefs - 1 Do
				If TypeOf(RefSet[Position].Value) <> FirstRefType Then
					EqualType = False;
					Break;
				EndIf;
			EndDo;
			
			If EqualType Then
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Места использования элементов ""%1"" (%2)'; en = 'Usage instances of items ""%1"" (%2)'; pl = 'Miejsca zastosowania elementów ""%1"" (%2)';es_ES = 'Lugares de uso de los elementos ""%1"" (%2)';es_CO = 'Lugares de uso de los elementos ""%1"" (%2)';tr = 'Nesne kullanım konumları ""%1"" (%2)';it = 'Instanze di uso degli elementi ""%1"" (%2)';de = 'Verwendungsorte der Elemente ""%1"" (%2)'"), 
					RefSet[0].Value.Metadata().Presentation(),
					TotalRefs);
			Else		
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Места использования элементов (%1)'; en = 'Usage instances of items (%1)'; pl = 'Miejsca zastosowania elementów (%1)';es_ES = 'Lugares de uso de los elementos (%1)';es_CO = 'Lugares de uso de los elementos (%1)';tr = 'Nesne kullanım konumları (%1)';it = 'Instanze di uso degli elementi  (%1)';de = 'Verwendungsorte der Elemente (%1)'"), 
					TotalRefs);
			EndIf;
		EndIf;
		
	EndIf;
		
	Return NStr("ru = 'Места использования элементов'; en = 'Item usage instances'; pl = 'Miejsca użycia elementów';es_ES = 'Ubicaciones de uso de artículos';es_CO = 'Ubicaciones de uso de artículos';tr = 'Öğe kullanım yerleri';it = 'Istanze uso elemento';de = 'Artikel Verwendungsorte'");

EndFunction

#EndRegion

#EndIf