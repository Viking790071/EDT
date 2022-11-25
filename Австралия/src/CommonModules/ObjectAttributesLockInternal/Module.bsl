////////////////////////////////////////////////////////////////////////////////
// Object attribute lock subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Internal

// Checks whether the attribute lock is allowed for a metadata object.
//
// Parameters:
//  FullName - String - full name of a metadata object.
//
Function LockSupported(FullName) Export
	
	Objects = New Map;
	SSLSubsystemsIntegration.OnDefineObjectsWithLockedAttributes(Objects);
	ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes(Objects);
	
	Return Objects[FullName] <> Undefined;
	
EndFunction

#EndRegion

#Region Private

// Sets up the object form for subsystem operations:
// - adds the AttributeLockParameters attribute that can be used to store internal data.
// - adds the AllowObjectAttributeEdit command and button (if sufficient rights are available).
//
Procedure PrepareForm(Form, Ref, LockButtonGroup, LockButtonTitle) Export
	
	String100TypeDescription = New TypeDescription("String",,New StringQualifiers(100));
	TypesDetailsBoolean = New TypeDescription("Boolean");
	ArrayTypeDescription = New TypeDescription("ValueList");
	
	FormAttributes = New Map;
	For each FormAttribute In Form.GetAttributes() Do
		FormAttributes.Insert(FormAttribute.Name, FormAttribute.Title);
	EndDo;
	
	// Adding attributes to form.
	AttributesToAdd = New Array;
	AttributesToAdd.Add(New FormAttribute("AttributeEditProhibitionParameters", New TypeDescription("ValueTable")));
	AttributesToAdd.Add(New FormAttribute("AttributeName",            String100TypeDescription, "AttributeEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("Presentation",           String100TypeDescription, "AttributeEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("EditingAllowed", TypesDetailsBoolean,    "AttributeEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("ItemsToLock",     ArrayTypeDescription,    "AttributeEditProhibitionParameters"));
	AttributesToAdd.Add(New FormAttribute("EditRight",     TypesDetailsBoolean,    "AttributeEditProhibitionParameters"));
	
	Form.ChangeAttributes(AttributesToAdd);
	
	AttributesToLock = Common.ObjectManagerByRef(Ref).GetObjectAttributesToLock();
	AllAttributesEditProhibited = True;
	
	For Each AttributeToLock In AttributesToLock Do
		
		AttributeDetails = Form.AttributeEditProhibitionParameters.Add();
		
		InformationOnAttributeToLock = StrSplit(AttributeToLock, ";", False);
		AttributeDetails.AttributeName = InformationOnAttributeToLock[0];
		
		If InformationOnAttributeToLock.Count() > 1 Then
			ItemsToLock = StrSplit(InformationOnAttributeToLock[1], ",", False);
			For Each ItemToLock In ItemsToLock Do
				AttributeDetails.ItemsToLock.Add(TrimAll(ItemToLock));
			EndDo;
		EndIf;
		
		ObjectMetadata = Ref.Metadata();
		IsChartOfAccounts = Common.IsChartOfAccounts(ObjectMetadata);
		ThereAreStandardTabularSections = IsChartOfAccounts Or Common.IsChartOfCalculationTypes(ObjectMetadata);
		
		AttributeOrTabularSectionMetadata = ObjectMetadata.Attributes.Find(AttributeDetails.AttributeName);
		If AttributeOrTabularSectionMetadata = Undefined AND IsChartOfAccounts Then
			AttributeOrTabularSectionMetadata = ObjectMetadata.AccountingFlags.Find(AttributeDetails.AttributeName);
		EndIf;
		StandardAttributeOrStandardTabularSection = False;
		
		If AttributeOrTabularSectionMetadata = Undefined Then
			AttributeOrTabularSectionMetadata = ObjectMetadata.TabularSections.Find(AttributeDetails.AttributeName);
			
			If AttributeOrTabularSectionMetadata = Undefined
			   AND ThereAreStandardTabularSections
			   AND Common.IsStandardAttribute(ObjectMetadata.StandardTabularSections, AttributeDetails.AttributeName) Then
					AttributeOrTabularSectionMetadata = ObjectMetadata.StandardTabularSections[AttributeDetails.AttributeName];
					StandardAttributeOrStandardTabularSection = True;
			EndIf;
			If AttributeOrTabularSectionMetadata = Undefined Then
				If Common.IsStandardAttribute(ObjectMetadata.StandardAttributes, AttributeDetails.AttributeName) Then
					AttributeOrTabularSectionMetadata = ObjectMetadata.StandardAttributes[AttributeDetails.AttributeName];
					StandardAttributeOrStandardTabularSection = True;
				EndIf;
			EndIf;
		EndIf;
		
		If AttributeOrTabularSectionMetadata = Undefined Then
			AttributeDetails.Presentation = FormAttributes[AttributeDetails.AttributeName];
			
			AttributeDetails.EditRight = True;
			AllAttributesEditProhibited = False;
		Else
			AttributeDetails.Presentation = AttributeOrTabularSectionMetadata.Presentation();
			
			If StandardAttributeOrStandardTabularSection Then
				RightToEdit = AccessRight("Edit", ObjectMetadata, , AttributeOrTabularSectionMetadata.Name);
			Else
				RightToEdit = AccessRight("Edit", AttributeOrTabularSectionMetadata);
			EndIf;
			If RightToEdit Then
				AttributeDetails.EditRight = True;
				AllAttributesEditProhibited = False;
			EndIf;
		EndIf;
	EndDo;
	
	FillRelatedItems(Form);
	
	// Adding command and button (if sufficient rights are available).
	If Users.RolesAvailable("EditObjectAttributes")
	   AND AccessRight("Edit", Ref.Metadata())
	   AND NOT AllAttributesEditProhibited Then
		
		// Adding command
		Command = Form.Commands.Add("AllowObjectAttributeEdit");
		Command.Title = ?(IsBlankString(LockButtonTitle), NStr("ru = 'Разрешить редактирование реквизитов'; en = 'Allow editing attributes'; pl = 'Zezwalaj na edycję atrybutów';es_ES = 'Permitir la edición de atributos';es_CO = 'Permitir la edición de atributos';tr = 'Öznitelikleri düzenlemeye izin ver';it = 'Consentire la modifica degli attributi';de = 'Bearbeitung von Attributen zulassen'"), LockButtonTitle);
		Command.Action = "Attachable_AllowObjectAttributesEditing";
		Command.Picture = PictureLib.AllowObjectAttributeEdit;
		Command.ModifiesStoredData = True;
		
		// Adding button
		ParentGroup = ?(LockButtonGroup <> Undefined, LockButtonGroup, Form.CommandBar);
		Button = Form.Items.Add("AllowObjectAttributeEdit", Type("FormButton"), ParentGroup);
		Button.OnlyInAllActions = True;
		Button.CommandName = "AllowObjectAttributeEdit";
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the PrepareForm procedure.
// Supplements an array of form items to be locked with the linked items.
Procedure FillRelatedItems(Form)
	
	Filter = New Structure("AttributeName", Undefined);
	
	For Each FormItem In Form.Items Do
		
		If TypeOf(FormItem) = Type("FormField")
		   AND FormItem.Type <> FormFieldType.LabelField
		 Or TypeOf(FormItem) = Type("FormTable") Then
		
			ParsedDataPath = StrSplit(FormItem.DataPath, ".", False);
			
			ParsedDataPathCount = ParsedDataPath.Count();
			
			If ParsedDataPathCount = 2 Or ParsedDataPathCount = 1 Then
				Filter.AttributeName = ParsedDataPath[ParsedDataPathCount - 1];
				Rows = Form.AttributeEditProhibitionParameters.FindRows(Filter);
				If Rows.Count() > 0 Then
					Rows[0].ItemsToLock.Add(FormItem.Name);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
