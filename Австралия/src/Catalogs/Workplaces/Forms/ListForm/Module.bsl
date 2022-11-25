
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CurrentWorksPlace = EquipmentManagerClientReUse.GetClientWorkplace();
	List.Parameters.SetParameterValue("CurrentWorksPlace", CurrentWorksPlace); 
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	SystemInfo = New SystemInfo();
	ClientID = Upper(SystemInfo.ClientID);
	
	Workplace = GetWorkplaceByClientID(ClientID);
	
	If Not Workplace = Undefined Then
		
		Cancel = True;
			                  
		Text = NStr("en = 'It is not required to create new workplace. 
		            |It is already created for this client identifier.
		            |Open an existing workplace?'; 
		            |ru = 'Создание нового рабочего места не требуется. 
		            |Для данного идентификатора клиента оно уже создано.
		            |Открыть существующее рабочее место?';
		            |pl = 'Nie jest wymagane tworzenie nowego miejsca pracy.
		            |Jest już utworzone dla tego identyfikatora klienta.
		            |Czy otworzyć istniejące miejsce pracy?';
		            |es_ES = 'No se requiere crear un nuevo lugar de trabajo.
		            |Ya está creado para este identificador del cliente.
		            |¿Abrir un lugar de trabajo ya existente?';
		            |es_CO = 'No se requiere crear un nuevo lugar de trabajo.
		            |Ya está creado para este identificador del cliente.
		            |¿Abrir un lugar de trabajo ya existente?';
		            |tr = 'Yeni çalışma alanı oluşturmak zorunlu değildir.
		            |Bu istemci tanımlayıcısı için çalışma alanı zaten oluşturuldu.
		            |Mevcut çalışma alanlarından biri açılsın mı?';
		            |it = 'Non è richiesta la creazione di una nuova postazione di lavoro. 
		            |È già stata creata per l''identificativo di questo client. 
		            |Aprire la postazione di lavoro esistente?';
		            |de = 'Es ist nicht erforderlich, einen neuen Arbeitsplatz zu erstellen. 
		            |Es ist bereits für diese Client-ID erstellt. 
		            |Einen vorhandenen Arbeitsplatz öffnen?'");
		Notification = New NotifyDescription("ListBeforeAddingRowEnd", ThisObject, Workplace);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ListBeforeAddingRowEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes AND Not IsBlankString(Parameters) Then
		ShowValue(, Parameters);
	EndIf;  
	
EndProcedure

&AtServer
Function GetWorkplaceByClientID(ID)
	
	Result = Undefined;
	
	Query = New Query("
	|SELECT
	|    Workplaces.Ref
	|FROM
	|    Catalog.Workplaces AS Workplaces
	|WHERE
	|    Workplaces.Code = &ID");
	
	Query.SetParameter("ID", ID);
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		Result = SelectionDetailRecords.Ref;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	FontMainSetting = StyleFonts.FontDialogAndMenu;
	
	// List
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Current");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontMainSetting);

EndProcedure

#EndRegion