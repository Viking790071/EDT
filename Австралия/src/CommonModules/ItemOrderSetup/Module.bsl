#Region Public

// Fills in a value of an additional order attribute for the object.
//
// Parameters:
//  Source - Object - an object to be written.
//  Cancel    - Boolean - indicates whether the object record is canceled.
Procedure FillOrderingAttributeValue(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
		Return; 
	EndIf;
	
	// Skipping the calculation of a new order if the cancellation flag is set in the handler.
	If Cancel Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	// Checking whether the object has an additional order attribute.
	Information = GetInformationForMoving(Source.Ref.Metadata());
	If Not ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Return;
	EndIf;
	
	// The order is reassigned upon moving an item to another group.
	If Information.HasParent AND Common.ObjectAttributeValue(Source.Ref, "Parent") <> Source.Parent Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
	// Calculating a new item order value.
	If Source.AdditionalOrderingAttribute = 0 Then
		Source.AdditionalOrderingAttribute =
			ItemsOrderSetupInternal.GetNewAdditionalOrderingAttributeValue(
					Information,
					?(Information.HasParent, Source.Parent, Undefined),
					?(Information.HasOwner, Source.Owner, Undefined));
	EndIf;
	
EndProcedure

// Resets a value of an additional order attribute for the object.
//
// Parameters:
//  Source          - Object - an object created by copying.
//  CopiedObject - Ref - an original object that is a source for copying.
Procedure ClearOrderAttributeValue(Source, CopiedObject) Export
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	Information = GetInformationForMoving(Source.Ref.Metadata());
	If ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
EndProcedure

// Returns a structure with information on object metadata.
// 
// Parameters:
//  ObjectMetadata - MetadataObject - metadata of the object being moved.
//
// Returns:
//  Structure - metadata object information.
Function GetInformationForMoving(ObjectMetadata) Export
	
	Information = New Structure;
	
	AttributeMetadata = ObjectMetadata.Attributes.AdditionalOrderingAttribute;
	
	Information.Insert("FullName",    ObjectMetadata.FullName());
	
	IsCatalog = Metadata.Catalogs.Contains(ObjectMetadata);
	IsCCT        = Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata);
	
	If IsCatalog OR IsCCT Then
		
		Information.Insert("HasGroups", ObjectMetadata.Hierarchical
			AND ?(IsCCT, True, ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems));
		
		Information.Insert("ForGroups",     (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForItem));
		Information.Insert("ForItems", (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForFolder));
		Information.Insert("HasParent",  ObjectMetadata.Hierarchical);
		Information.Insert("FoldersOnTop", ?(NOT Information.HasParent, False, ObjectMetadata.FoldersOnTop));
		Information.Insert("HasOwner", ?(IsCCT, False, (ObjectMetadata.Owners.Count() <> 0)));
		
	Else
		
		Information.Insert("HasGroups",   False);
		Information.Insert("ForGroups",     False);
		Information.Insert("ForItems", True);
		Information.Insert("HasParent", False);
		Information.Insert("HasOwner", False);
		Information.Insert("FoldersOnTop", False);
		
	EndIf;
	
	Return Information;
	
EndFunction

#EndRegion

#Region Internal

// Moves an item up or down in a list.
Procedure Attachable_MoveItem(Ref, ExecutionParameters) Export
	Direction = ExecutionParameters.CommandDetails.ID;
	ErrorText = ItemsOrderSetupInternal.MoveItem(ExecutionParameters.Source, Ref, Direction);
	ExecutionParameters.Result.Text = ErrorText;
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds. 
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "ItemOrderSetup";
	Kind.SubmenuName  = "ItemOrderSetup";
	Kind.Title   = NStr("ru = 'Настройка порядка элементов'; en = 'Item order setup'; pl = 'Ustawienia kolejności elementów';es_ES = 'Artículo configuración del pedido';es_CO = 'Artículo configuración del pedido';tr = 'Nesne düzeni kurulumu';it = 'Impostazione dell''ordine degli elementi';de = 'Artikel bestellen Setup'");
	Kind.FormGroupType = FormGroupType.ButtonGroup;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject. 
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	ObjectsWithCustomizableOrder = New Array;
	For Each Type In Metadata.DefinedTypes.ObjectWithCustomOrder.Type.Types() Do
		MetadataObject = Metadata.FindByType(Type);
		ObjectsWithCustomizableOrder.Add(MetadataObject.FullName());
	EndDo;
	
	OutputCommands = False;
	For Each Source In Sources.Rows Do
		If ObjectsWithCustomizableOrder.Find(Source.FullName) <> Undefined Then
			OutputCommands = True;
			Break;
		EndIf;
	EndDo;
	If Not OutputCommands Then
		Return;
	EndIf;
	
	Command = Commands.Add();
	Command.Kind = "ItemOrderSetup";
	Command.ID = "Up";
	Command.Presentation = NStr("ru = 'Переместить элемент вверх'; en = 'Move item up'; pl = 'Przenieś element do góry';es_ES = 'Mover el artículo arriba';es_CO = 'Mover el artículo arriba';tr = 'Yukarı taşı';it = 'Spostare elemento verso l''alto';de = 'Element nach oben versetzen'");
	Command.Order = 1;
	Command.Picture = PictureLib.MoveUp;
	Command.ChangesSelectedObjects = True;
	Command.MultipleChoice = False;
	Command.Handler = "ItemOrderSetup.Attachable_MoveItem";
	Command.ButtonRepresentation = ButtonRepresentation.Picture;
	Command.Purpose = "ForList";
	
	Command = Commands.Add();
	Command.Kind = "ItemOrderSetup";
	Command.ID = "Down";
	Command.Presentation = NStr("ru = 'Переместить элемент вниз'; en = 'Move item down'; pl = 'Przenieś element w dół';es_ES = 'Mover el artículo abajo';es_CO = 'Mover el artículo abajo';tr = 'Aşağı taşı';it = 'Spostare elemento verso il basso';de = 'Element nach unten versetzen'");
	Command.Order = 2;
	Command.Picture = PictureLib.MoveDown;
	Command.ChangesSelectedObjects = True;
	Command.MultipleChoice = False;
	Command.Handler = "ItemOrderSetup.Attachable_MoveItem";
	Command.ButtonRepresentation = ButtonRepresentation.Picture;
	Command.Purpose = "ForList";
	
EndProcedure

#EndRegion

#Region Private

Function ObjectHasAdditionalOrderingAttribute(Object, Information)
	
	If Not Information.HasParent Then
		// Catalog catalog is non-hierarchical, it means that the attribute exists.
		Return True;
		
	ElsIf Object.IsFolder AND Not Information.ForGroups Then
		// This is a group, but the order is not assigned to groups.
		Return False;
		
	ElsIf Not Object.IsFolder AND Not Information.ForItems Then
		// This is an item, the order is not assigned to items.
		Return False;
		
	Else
		Return True;
		
	EndIf;
	
EndFunction

#EndRegion
