#Region Public

// Determines that the specified event is an event of property set change.
//
// Parameters:
//  Form - ClientApplicationForm - a form from which the notification data processor was called.
//  EventName - String - a name of the processed event.
//  Parameter - Arbitrary - parameters passed in the event.
//
// Returns:
//  Boolean - if True, it is a notification of property set change, and it needs to be processed in 
//           the form.
//
Function ProcessNofifications(Form, EventName, Parameter) Export
	
	If NOT Form.Properties_UseProperties
	 OR NOT Form.Properties_UseAddlAttributes Then
		
		Return False;
	EndIf;
	
	If EventName = "Write_AdditionalDataAndAttributeSets" Then
		If Not Parameter.Property("Ref") Then
			Return True;
		Else
			Return Form.Properties_ObjectAdditionalAttributeSets.FindByValue(Parameter.Ref) <> Undefined;
		EndIf;
		
	ElsIf EventName = "Write_AdditionalAttributesAndInfo" Then
		
		If Form.PropertiesParameters.Property("DeferredInitializationExecuted")
			AND Not Form.PropertiesParameters.DeferredInitializationExecuted
			Or Not Parameter.Property("Ref") Then
			Return True;
		Else
			Filter = New Structure("Property", Parameter.Ref);
			Return Form.Properties_AdditionalAttributeDetails.FindRows(Filter).Count() > 0;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Updates visibility, availability, and required filling of additional attributes.
// 
//
// Parameters:
//  Form - ManagedFrom - a form being processed.
//  Object - FormDataStructure - details of the object for which properties are enabled, if the 
//                                  property is not specified or Undefined, the object will be taken 
//                                  from the Object form attribute.
//
Procedure UpdateAdditionalAttributesDependencies(Form, Object = Undefined) Export
	
	If NOT Form.Properties_UseProperties
	 OR NOT Form.Properties_UseAddlAttributes Then
		
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	For Each DependentAttributeDetails In Form.Properties_DependentAdditionalAttributesDescription Do
		If DependentAttributeDetails.OutputAsHyperlink Then
			ProcessedItem = StrReplace(DependentAttributeDetails.ValueAttributeName, "AdditionalRequisiteValue_", "Group_");
		Else
			ProcessedItem = DependentAttributeDetails.ValueAttributeName;
		EndIf;
		
		If DependentAttributeDetails.AvailabilityCondition <> Undefined Then
			Parameters = New Structure;
			Parameters.Insert("ParameterValues", DependentAttributeDetails.AvailabilityCondition.ParameterValues);
			Parameters.Insert("Form", Form);
			Parameters.Insert("ObjectDetails", ObjectDetails);
			Result = Eval(DependentAttributeDetails.AvailabilityCondition.ConditionCode);
			
			Item = Form.Items[ProcessedItem];
			If Item.Enabled <> Result Then
				Item.Enabled = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.VisibilityCondition <> Undefined Then
			Parameters = New Structure;
			Parameters.Insert("ParameterValues", DependentAttributeDetails.VisibilityCondition.ParameterValues);
			Parameters.Insert("Form", Form);
			Parameters.Insert("ObjectDetails", ObjectDetails);
			Result = Eval(DependentAttributeDetails.VisibilityCondition.ConditionCode);
			
			Item = Form.Items[ProcessedItem];
			If Item.Visible <> Result Then
				Item.Visible = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.FillingRequiredCondition <> Undefined Then
			If Not DependentAttributeDetails.RequiredToFill Then
				Continue;
			EndIf;
			
			Parameters = New Structure;
			Parameters.Insert("ParameterValues", DependentAttributeDetails.FillingRequiredCondition.ParameterValues);
			Parameters.Insert("Form", Form);
			Parameters.Insert("ObjectDetails", ObjectDetails);
			Result = Eval(DependentAttributeDetails.FillingRequiredCondition.ConditionCode);
			
			Item = Form.Items[ProcessedItem];
			If Not DependentAttributeDetails.OutputAsHyperlink
				AND Item.AutoMarkIncomplete <> Result Then
				Item.AutoMarkIncomplete = Result;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Checks if there are dependent additional attributes on the form and attaches idle handler of 
// checking attribute dependencies if needed.
//
// Parameters:
//  Form - ClientApplicationForm - a form being checked.
//
Procedure AfterImportAdditionalAttributes(Form) Export
	
	If NOT Form.Properties_UseProperties
		Or NOT Form.Properties_UseAddlAttributes Then
		
		Return;
	EndIf;
	
	If Form.Properties_DependentAdditionalAttributesDescription.Count() > 0 Then
		Form.AttachIdleHandler("UpdateAdditionalAttributesDependencies", 2);
	EndIf;
	
EndProcedure

// Command handler from forms, to which additional properties are attached.
// 
// Parameters:
//  Form - ClientApplicationForm - a form with additional attributes preliminarily set in the 
//                          PropertyManagement.OnCreateAtServer() procedure.
//  Item - FormField, FormCommand - an item whose clicking is to be processed.
//  StandardProcessing - Boolean - a returned parameter, if interactive actions with the user are 
//                          needed, it is set to False.
//
Procedure ExecuteCommand(Form, Item  = Undefined, StandardProcessing  = Undefined) Export
	
	If Item = Undefined Then
		CommandName = "EditAdditionalAttributesComposition";
	ElsIf TypeOf(Item) = Type("FormCommand") Then
		CommandName = Item.Name;
	Else
		AttributeValue = Form[Item.Name];
		If Not ValueIsFilled(AttributeValue) Then
			EditAttributeHyperlink(Form, True, Item);
			StandardProcessing = False;
		EndIf;
		Return;
	EndIf;
	
	If CommandName = "EditAdditionalAttributesComposition" Then
		EditPropertiesContent(Form);
	ElsIf CommandName = "EditAttributeHyperlink" Then
		EditAttributeHyperlink(Form);
	EndIf;
EndProcedure

#EndRegion

#Region Private

// Opens the editing form of an additional attribute set.
//
// Parameters:
//  Form - ClientApplicationForm - a form the method is called from.
//
Procedure EditPropertiesContent(Form)
	
	Sets = Form.Properties_ObjectAdditionalAttributeSets;
	
	If Sets.Count() = 0
	 OR NOT ValueIsFilled(Sets[0].Value) Then
		
		ShowMessageBox(,
			NStr("ru = 'Не удалось получить наборы дополнительных реквизитов объекта.
			           |
			           |Возможно у объекта не заполнены необходимые реквизиты.'; 
			           |en = 'Cannot receive sets of additional object attributes.
			           |
			           |Required object attributes might not be filled in.'; 
			           |pl = 'Nie udało się uzyskać zestawy dodatkowych rekwizytów obiektu. 
			           |
			           |Być może u obiektu nie zostały wypełnione wymagane rekwizyty.';
			           |es_ES = 'Fallado a obtener los conjuntos de los requisitos adicionales del objeto.
			           |
			           |Probablemente los requisitos necesarios no se han rellenado para el documento.';
			           |es_CO = 'Fallado a obtener los conjuntos de los requisitos adicionales del objeto.
			           |
			           |Probablemente los requisitos necesarios no se han rellenado para el documento.';
			           |tr = 'Nesnenin ek bilgi kümeleri alınamadı.
			           |
			           |Nesne için gereken özellikler doldurulmamış olabilir.';
			           |it = 'Impossibile acquisire set di requisiti aggiuntivi dell''oggetto.
			           |
			           |I requisiti desiderati potrebbero non essere compilati.';
			           |de = 'Fehler beim Abrufen zusätzlicher Objektattribute.
			           |
			           |Möglicherweise ist das Objekt nicht mit den erforderlichen Attributen ausgefüllt.'"));
	
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ShowAdditionalAttributes");
		
		OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm", FormParameters);
		
		MigrationParameters = New Structure;
		MigrationParameters.Insert("Set", Sets[0].Value);
		MigrationParameters.Insert("Property", Undefined);
		MigrationParameters.Insert("IsAdditionalInfo", False);
		
		BeginningLength = StrLen("AdditionalRequisiteValue_");
		IsFormField = (TypeOf(Form.CurrentItem) = Type("FormField"));
		If IsFormField AND Upper(Left(Form.CurrentItem.Name, BeginningLength)) = Upper("AdditionalRequisiteValue_") Then
			
			SetID   = StrReplace(Mid(Form.CurrentItem.Name, BeginningLength +  1, 36), "x","-");
			PropertyID = StrReplace(Mid(Form.CurrentItem.Name, BeginningLength + 38, 36), "x","-");
			
			If StringFunctionsClientServer.IsUUID(Lower(SetID)) Then
				MigrationParameters.Insert("Set", SetID);
			EndIf;
			
			If StringFunctionsClientServer.IsUUID(Lower(PropertyID)) Then
				MigrationParameters.Insert("Property", PropertyID);
			EndIf;
		EndIf;
		
		Notify("Go_AdditionalDataAndAttributeSets", MigrationParameters);
	EndIf;
	
EndProcedure

Procedure EditAttributeHyperlink(Form, HyperlinkAction = False, Item = Undefined)
	If Not HyperlinkAction Then
		ButtonName = Form.CurrentItem.Name;
		UniquePart = StrReplace(ButtonName, "Button_", "");
		AttributeName = "AdditionalRequisiteValue_" + UniquePart;
	Else
		AttributeName = Item.Name;
		UniquePart = StrReplace(AttributeName, "AdditionalRequisiteValue_", "");
	EndIf;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ValueAttributeName", AttributeName);
	
	AttributesDetails = Form.Properties_AdditionalAttributeDetails.FindRows(FilterParameters);
	If AttributesDetails.Count() <> 1 Then
		Return;
	EndIf;
	AttributeDetails = AttributesDetails[0];
	
	If Not AttributeDetails.RefTypeString Then
		If Form.Items[AttributeName].Type = FormFieldType.InputField Then
			Form.Items[AttributeName].Type = FormFieldType.LabelField;
			Form.Items[AttributeName].Hyperlink = True;
		Else
			Form.Items[AttributeName].Type = FormFieldType.InputField;
			If AttributeDetails.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
				OR AttributeDetails.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				ChoiceParameter = ?(ValueIsFilled(AttributeDetails.AdditionalValuesOwner),
					AttributeDetails.AdditionalValuesOwner, AttributeDetails.Property);
				ChoiceParametersArray = New Array;
				ChoiceParametersArray.Add(New ChoiceParameter("Filter.Owner", ChoiceParameter));
				
				Form.Items[AttributeName].ChoiceParameters = New FixedArray(ChoiceParametersArray);
			EndIf;
		EndIf;
		
		Return;
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("AttributeName", AttributeName);
	OpeningParameters.Insert("ValueType", AttributeDetails.ValueType);
	OpeningParameters.Insert("AttributeDescription", AttributeDetails.Description);
	OpeningParameters.Insert("RefTypeString", AttributeDetails.RefTypeString);
	OpeningParameters.Insert("AttributeValue", Form[AttributeName]);
	OpeningParameters.Insert("ReadOnly", Form.ReadOnly);
	If AttributeDetails.RefTypeString Then
		OpeningParameters.Insert("RefAttributeName", "ReferenceAdditionalAttributeValue_" + UniquePart);
	Else
		OpeningParameters.Insert("Property", AttributeDetails.Property);
		OpeningParameters.Insert("AdditionalValuesOwner", AttributeDetails.AdditionalValuesOwner);
	EndIf;
	NotifyDescription = New NotifyDescription("EditAttributeHyperlinkCompletion", PropertyManagerClient, Form);
	OpenForm("CommonForm.EditHyperlink", OpeningParameters,,,,, NotifyDescription);
EndProcedure

Procedure EditAttributeHyperlinkCompletion(Result, AdditionalParameters) Export
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	Form = AdditionalParameters;
	Form[Result.AttributeName] = Result.Value;
	If Result.RefTypeString Then
		Form[Result.RefAttributeName] = Result.FormattedString;
	EndIf;
	Form.Modified = True;
EndProcedure

#EndRegion