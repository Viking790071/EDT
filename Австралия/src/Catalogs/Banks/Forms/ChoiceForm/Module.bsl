
///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

&AtClient
Procedure PickFromClassifier(Command)
	
	FormParameters = New Structure("CloseOnChoice, MultipleChoice", True, True);
	OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);

EndProcedure

#Region ProcedureFormEventHandlers

// Procedure form event handler OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ListOfFoundBanks") Then
		
		DriveClientServer.SetListFilterItem(List, "Ref", Parameters.ListOfFoundBanks, True,DataCompositionComparisonType.InList);
		Items.List.ChoiceFoldersAndItems = FoldersAndItemsUse.Items;
		Items.List.Representation = TableRepresentation.List;
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

// Form event handler procedure NotificationProcessing
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAfterAdd" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineBankPickNeedFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		FormParameters = New Structure("ChoiceMode, CloseOnChoice, MultipleChoice", True, True, True);
		OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);
		
	Else
		
		If AdditionalParameters.IsFolder Then
			
			OpenForm("Catalog.Banks.FolderForm", New Structure("IsFolder",True), ThisObject);
			
		Else
			
			OpenForm("Catalog.Banks.ObjectForm");
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	QuestionText = NStr("en = 'Do you want to choose bank from the bank classifier or create it manually?
	                    |Click Yes to choose bank from the classifier and modify it if necessary.
	                    |Click No to create new record from scratch.'; 
	                    |ru = '???? ???????????? ?????????????? ???????? ???? ???????????????????????????? ???????????? ?????? ?????????????? ?????? ???????????????
	                    |?????????????? ???? ?????????? ?????????????? ???????? ???? ???????????????????????????? ?? ?????? ?????????????????????????? ?????????????????????????????? ?????? ??????????????.
	                    |?????????????? ?????? ?????????? ?????????????? ?????????? ??????????????.';
	                    |pl = 'Czy chcesz wybra?? bank z klasyfikatora bank??w lub utworzy?? go r??cznie?
	                    |Kliknij Tak, aby wybra?? bank z klasyfikatora i zmodyfikuj go, je??li to konieczne.
	                    |Kliknij Nie, aby utworzy?? nowy zapis od zera.';
	                    |es_ES = '??Quiere elegir el banco desde el clasificador de banco, o crearlo manualmente?
	                    |Hacer clic en S?? para elegir el banco desde el clasificador y modificarlo si es necesario.
	                    |Hacer clic en No para crear un nuevo registro desde cero.';
	                    |es_CO = '??Quiere elegir el banco desde el clasificador de banco, o crearlo manualmente?
	                    |Hacer clic en S?? para elegir el banco desde el clasificador y modificarlo si es necesario.
	                    |Hacer clic en No para crear un nuevo registro desde cero.';
	                    |tr = 'Banka s??n??fland??r??c??s??ndan banka se??mek mi yoksa manuel olarak olu??turmak m?? istiyorsunuz? 
	                    |S??n??fland??r??c??dan banka se??mek ve gerekiyorsa de??i??tirmek i??in Evet''i t??klay??n. 
	                    |S??f??rdan yeni kay??t olu??turmak i??in Hay??r''a t??klay??n.';
	                    |it = 'Vuoi scegliere tra una banca dal classificatore banche o crearla manualmente?
	                    |Cliccare ""S??"" per scegliere la banca dal classificatore e di modificarla se necessario.
	                    |Cliccare ""No"" per creare una nuova registrazione da zero.';
	                    |de = 'M??chten Sie eine Bank aus dem Bankklassifikator ausw??hlen oder manuell anlegen?
	                    |Klicken Sie auf Ja, um eine Bank aus dem Klassifikator auszuw??hlen, und ??ndern Sie sie bei Bedarf.
	                    |Klicken Sie auf Nein, um einen neuen Datensatz von Grund auf neu zu erstellen.'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsFolder", Group);
	NotifyDescription = New NotifyDescription("DetermineBankPickNeedFromClassifier", ThisObject, AdditionalParameters);
	
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

#EndRegion

#EndRegion
