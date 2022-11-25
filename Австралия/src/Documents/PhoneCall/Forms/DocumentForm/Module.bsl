///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Variables

&AtClient
Var ChoiceContext;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		Interactions.SetSubjectByFillingData(Parameters, Topic);
	EndIf;
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	If Object.Ref.IsEmpty() Then
		Object.Incoming = NOT (Parameters.Property("Basis")
		AND NOT (Parameters.Basis = False OR Parameters.Basis = Undefined));
	EndIf;
	
	// Determining types of contacts that can be created.
	ContactsToInteractivelyCreateList = Interactions.CreateValueListOfInteractivelyCreatedContacts();
	Items.CreateContact.Visible      = ContactsToInteractivelyCreateList.Count() > 0;

	// Preparing interaction notifications.
	Interactions.PrepareNotifications(ThisObject,Parameters);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	If Parameters.Property("ParticipantData") AND Object.SubscriberContact <> Parameters.ParticipantData.Contact Then
		FillBasedOnParticipant(Parameters.ParticipantData);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnCreateAtServer(ThisObject);
	EndIf;
	
	OnCreateAndOnReadAtServer();
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "PhoneCall");
	
	// StandardSubsystems.FilesOperations
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		FilesHyperlink = ModuleFilesOperations.FilesHyperlink();
		FilesHyperlink.Placement = "CommandBar";
		ModuleFilesOperations.OnCreateAtServer(ThisObject, FilesHyperlink);
	EndIf;
	// End StandardSubsystems.FilesOperations
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	OnCreateAndOnReadAtServer();
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	CheckContactCreationAvailability();
	
	// StandardSubsystems.FilesOperations
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OnOpen(ThisObject, Cancel);
	EndIf;
	// End StandardSubsystems.FilesOperations
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteMode, PostingMode)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	Interactions.BeforeWriteInteractionFromForm(ThisObject, CurrentObject, ContactsChanged);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Interactions.OnWriteInteractionFromForm(CurrentObject, ThisObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "PhoneCall");
	CheckContactCreationAvailability();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties
	
	InteractionsClient.ProcessNotification(ThisObject,EventName, Parameter, Source);
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "PhoneCall");
	CheckContactCreationAvailability();
	
	// StandardSubsystems.FilesOperations
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.NotificationProcessing(ThisObject, EventName);
	EndIf;
	// End StandardSubsystems.FilesOperations

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	InteractionsClient.ChoiceProcessingForm(ThisObject, SelectedValue, ChoiceSource, ChoiceContext);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure PagesDetailsAdditionallyOnChangePage(Item, CurrentPage)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		AND CurrentPage.Name = "AdditionalAttributesPage"
		AND Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("EmailOnly",                       False);
	OpeningParameters.Insert("PhoneOnly",                     True);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", True);
	OpeningParameters.Insert("ForContactSpecificationForm",        False);
	OpeningParameters.Insert("FormID",                UUID);
	
	InteractionsClient.SelectContact(Topic, Object.HowToContactSubscriber,
	         Object.SubscriberPresentation, Object.SubscriberContact, OpeningParameters);

EndProcedure

&AtClient
Procedure ContactPresentationOnChange(Item)
	
	CheckContactCreationAvailability();
	ContactsChanged = True;
	
EndProcedure

&AtClient
Procedure ContactOnChange(Item)
	
	InteractionsServerCall.PresentationAndAllContactInformationOfContact(Object.SubscriberContact,
	                                                                         Object.SubscriberPresentation,
	                                                                         Object.HowToContactSubscriber);
	CheckContactCreationAvailability();
	InteractionsClientServer.CheckContactsFilling(Object,ThisObject,"PhoneCall");
	ContactsChanged = True;
	
EndProcedure

&AtClient
Procedure ReviewAfterProcessSelection(Item, ValueSelected, StandardProcessing)
	
	InteractionsClient.ProcessSelectionInReviewAfterField(ReviewAfter, 
		ValueSelected, StandardProcessing, Modified);
	
EndProcedure

&AtClient
Procedure ReviewedOnChange(Item)
	
	Items.ReviewAfter.Enabled = NOT Reviewed;
	
EndProcedure

&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	InteractionsClient.SubjectStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDragCheck(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateContactComplete()

	InteractionsClient.CreateContact(
		Object.SubscriberPresentation, Object.HowToContactSubscriber, Object.Ref, ContactsToInteractivelyCreateList);

EndProcedure

&AtClient
Procedure LinkedInteractionsExecute()

	FilterParameters = New Structure;
	FilterParameters.Insert("Topic", Object.Topic);

	OpenForm("DocumentJournal.Interactions.ListForm", FilterParameters, ThisObject, , Window);

EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

#EndRegion

#Region Private

&AtServer
Procedure FillBasedOnParticipant(ParticipantData)
	
	Object.SubscriberContact = ParticipantData.Contact;
	If IsBlankString(ParticipantData.HowToContact) Then
		
		Object.HowToContactSubscriber = "";
		Interactions.FinishFillingContactsFields(Object.SubscriberContact,
			Object.SubscriberPresentation,
			Object.HowToContactSubscriber,
			Enums.ContactInformationTypes.Phone);
		
	Else
		
		Object.HowToContactSubscriber = ParticipantData.HowToContact;
		
	EndIf;
	
	Object.SubscriberPresentation = ParticipantData.Presentation;
	
EndProcedure

&AtServer
Procedure OnCreateAndOnReadAtServer()
	
	If Not Object.Ref.IsEmpty() Then
		Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
		DocumentDate = Object.Date;
	Else
		ContactsChanged = True;
		DocumentDate = CurrentSessionDate();
	EndIf;
	Items.ReviewAfter.Enabled = NOT Reviewed;
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

&AtClient
Procedure CheckContactCreationAvailability()
	
	Items.CreateContact.Enabled = (NOT Object.Ref.IsEmpty()) 
	                                      AND (Not ValueIsFilled(Object.SubscriberContact)) 
	                                      AND (Not IsBlankString(Object.SubscriberPresentation));
	
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion
