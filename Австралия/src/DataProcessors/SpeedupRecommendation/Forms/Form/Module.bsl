
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	CommonParameters = Common.CommonCoreParameters();
	RecommendedSize = CommonParameters.RecommendedRAM;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Cancel = True;
	
	SystemInfo = New SystemInfo;
	AvailableMemorySize = Round(SystemInfo.RAM / 1024, 1);
	
	If AvailableMemorySize >= RecommendedSize Then
		Return;
	EndIf;
	
	MessageText = NStr("ru = 'На компьютере установлено %1 Гб оперативной памяти.
		|Для того чтобы программа работала быстрее, 
		|рекомендуется увеличить объем памяти до %2 Гб.'; 
		|en = 'The computer has %1 GB of RAM.
		|For better application performance,
		|it is recommended that you increase the RAM size to %2 GB.'; 
		|pl = 'Na komputerze ustawiono %1 GB pamięci operacyjnej. 
		|Aby program pracował szybciej, 
		|zaleca się zwiększyć pojemność pamięci do %2 GB.';
		|es_ES = 'En el ordenador está instalado %1 GB de la memoria operativa.
		|Para que el programa funcione más rápido 
		|se recomienda aumentar el volumen de la memoria hasta %2 GB.';
		|es_CO = 'En el ordenador está instalado %1 GB de la memoria operativa.
		|Para que el programa funcione más rápido 
		|se recomienda aumentar el volumen de la memoria hasta %2 GB.';
		|tr = 'Bilgisayarda %1GB RAM yüklü. %2Programın daha hızlı çalışmasını sağlamak için 
		|bellek miktarını 
		|GB''ye yükseltmeniz önerilir.';
		|it = 'Il computer ha %1 GB di RAM.
		|Per migliori performance dell''applicazione,
		|si consiglia di incrementare la dimensione RAM a %2 GB.';
		|de = 'Ein %1 GB RAM ist auf dem Computer installiert.
		|Um die Arbeit des Programms zu beschleunigen,
		|wird empfohlen, den Speicherplatz auf bis zu %2 GB zu erhöhen.'");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, AvailableMemorySize, RecommendedSize);
	
	MessageTitle = NStr("ru = 'Рекомендация по повышению скорости работы'; en = 'Speedup recommendation'; pl = 'Zalecenie odnośnie zwiększenia szybkości pracy';es_ES = 'Recomendación de superar la velocidad del trabajo';es_CO = 'Recomendación de superar la velocidad del trabajo';tr = 'Çalışma hızının arttırılması ile ilgili öneri';it = 'Raccomandazioni per accellarazione funzionamento';de = 'Empfehlung zur Erhöhung der Arbeitsgeschwindigkeit'");
	
	QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionParameters.Title = MessageTitle;
	QuestionParameters.Picture = PictureLib.Warning32;
	QuestionParameters.Insert("CheckBoxText", NStr("ru = 'Не показывать в течение двух месяцев'; en = 'Remind in two months'; pl = 'Nie pokazuj w ciągu dwóch miesięcy';es_ES = 'No mostrar durante dos meses';es_CO = 'No mostrar durante dos meses';tr = 'İki ay içinde gösterme';it = 'Ricorda in 2 mesi';de = 'Zwei Monate lang nicht vorzeigen'"));
	
	Buttons = New ValueList;
	Buttons.Add("ContinueWork", NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
	
	NotifyDescription = New NotifyDescription("AfterShowRecommendation", ThisObject);
	StandardSubsystemsClient.ShowQuestionToUser(NotifyDescription, MessageText, Buttons, QuestionParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterShowRecommendation(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	RAMRecommendation = New Structure;
	RAMRecommendation.Insert("Show", Not Result.DoNotAskAgain);
	RAMRecommendation.Insert("PreviousShowDate", CommonClient.SessionDate());
	
	CommonServerCall.CommonSettingsStorageSave("UserCommonSettings",
		"RAMRecommendation", RAMRecommendation);
EndProcedure

#EndRegion
