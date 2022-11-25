#Region Public

// Prohibits editing specified attributes of an object form, and adds the Allow editing attributes 
// command to All actions.
// 
//
// Parameters:
//  Form - ClientApplicationForm - object form.
//  LockButtonGroup - FormGroup - used to modify the default placement of the lock button in the 
//                            object form.
//  LockButtonTitle - String - button title. The default value is Allow editing attributes.
//  Object - Undefined - take the object from Object form attribute.
//                          - FormDataStructure - by object type.
//
Procedure LockAttributes(Form, LockButtonGroup = Undefined, LockButtonTitle = "",
		Object = Undefined) Export
	
	ObjectDetails = ?(Object = Undefined, Form.Object, Object);
	
	// Determining whether the form is already prepared during an earlier call.
	FormPrepared = False;
	FormAttributes = Form.GetAttributes();
	For Each FormAttribute In FormAttributes Do
		If FormAttribute.Name = "AttributeEditProhibitionParameters" Then
			FormPrepared = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FormPrepared Then
		ObjectAttributesLockInternal.PrepareForm(Form,
			ObjectDetails.Ref, LockButtonGroup, LockButtonTitle);
	EndIf;
	
	IsNewObject = ObjectDetails.Ref.IsEmpty();
	
	// Enabling edit prohibition for form items related to the specified attributes.
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		For Each FormItemDescription In DescriptionOfAttributeToLock.ItemsToLock Do
			
			DescriptionOfAttributeToLock.EditingAllowed =
				DescriptionOfAttributeToLock.EditRight AND IsNewObject;
			
			FormItem = Form.Items.Find(FormItemDescription.Value);
			If FormItem <> Undefined Then
				If TypeOf(FormItem) = Type("FormField")
				   AND FormItem.Type <> FormFieldType.LabelField
				 Or TypeOf(FormItem) = Type("FormTable") Then
					FormItem.ReadOnly = NOT DescriptionOfAttributeToLock.EditingAllowed;
				Else
					FormItem.Enabled = DescriptionOfAttributeToLock.EditingAllowed;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If Form.Items.Find("AllowObjectAttributeEdit") <> Undefined Then
		Form.Items.AllowObjectAttributeEdit.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion
