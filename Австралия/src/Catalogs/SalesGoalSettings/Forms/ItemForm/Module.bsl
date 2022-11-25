
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SalesGoalDimensions.Ref AS Value,
		|	NOT SalesGoalSettingsDimensions.Dimension IS NULL AS Check
		|FROM
		|	Enum.SalesGoalDimensions AS SalesGoalDimensions
		|		LEFT JOIN Catalog.SalesGoalSettings.Dimensions AS SalesGoalSettingsDimensions
		|		ON (SalesGoalSettingsDimensions.Dimension = SalesGoalDimensions.Ref)
		|			AND (SalesGoalSettingsDimensions.Ref = &Ref)
		|
		|ORDER BY
		|	SalesGoalDimensions.Order";
	
	Query.SetParameter("Ref", Object.Ref);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		DimensionRow = Dimensions.Add(SelectionDetailRecords.Value, , SelectionDetailRecords.Check);
		
	EndDo;
	
	FormManagement();
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.Dimensions.Clear();
	
	For Each DimensionRow In Dimensions Do
		
		If DimensionRow.Check Then
			
			CurrentObjectDimension = CurrentObject.Dimensions.Add();
			CurrentObjectDimension.Dimension = DimensionRow.Value;
			
		EndIf;
		
	EndDo;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	DimensionsNotFilled = True;
	
	For Each DimensionRow In Dimensions Do
		
		If DimensionRow.Check Then
			
			DimensionsNotFilled = False;
			Break;
			
		EndIf;
		
	EndDo;
	
	If DimensionsNotFilled Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Choose at least one dimension'; ru = 'Выберите, как минимум, одно измерение';pl = 'Wybierz co najmniej jeden wymiar';es_ES = 'Elige al menos una dimensión';es_CO = 'Elige al menos una dimensión';tr = 'En az bir boyut seçin';it = 'Selezionare almeno una dimensione';de = 'Wählen Sie mindestens eine Dimension aus'"), , "Dimensions", , Cancel);
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

&AtClient
Procedure DimensionsCheckOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtServer
Procedure FormManagement()
	
	ProductsDimension = Dimensions.FindByValue(Enums.SalesGoalDimensions.Products);
	ProductWasSelected = ProductsDimension <> Undefined And ProductsDimension.Check;
	
	If Not ProductWasSelected Then
		Object.SpecifyQuantity = False;
	EndIf;
	
	Items.SpecifyQuantity.Enabled = ProductWasSelected;
	
EndProcedure

// StandardSubsystems.Properties
&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure
// End StandardSubsystems.Properties

#EndRegion
