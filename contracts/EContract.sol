pragma solidity >0.4.0;
contract EContract{
    uint contractNum;
    address admin;
    struct Individual{
        address ethAddress;
        bytes32 pid;//身份证号？
        bytes32 pubKey;
        mapping(bytes32=>bool) agrExsit;//-------------
        bytes32[] AAgreementIndexs;//作为甲方签署的合同
        bytes32[] BAgreementIndexs;//作为乙方签署的合同
        bool isUsed;
    }
    struct Enterprise{
        address ethAddress;
        bytes32 eid;//企业唯一标识
        bytes32 pubKey;
        //添加需要上链的企业信息
        bytes32 leagalRepresentative;//法定代表人
        bytes32 registerShare;//注册资本
        bytes32 fundTime;//成立日期
        bytes32 enterpriseType;//公司类型
        bytes32 registrar;//登记机关
        bytes32 endTime;//经营年限
        bytes32 service;//经营服务
        mapping(bytes32=>bool)agrExsit;//-------------
        bytes32[] AAgreementIndexs;//作为甲方签署的合同
        bytes32[] BAgreementIndexs;//作为乙方签署的合同
        bool isUsed;
    }
    struct Agreement{
        bytes32 cid;//合同唯一id标识
        address creater;
        string agreementOriLink;
        bool state;//1.未通过，2.通过
        mapping(address=>string) agreementSignedLink;
        mapping(address=>bool) agreed;//-------------
        mapping(address=>uint)usrs;//1-甲方,2-乙方
        bytes32 pri;
        bytes32 next;
        bool isUsed;
    }
    mapping(address=>Individual)mapIndividual;
    mapping(address=>Enterprise)mapEnterprise;
    mapping(bytes32=>Agreement) mapAgreement;
    constructor()public{
        admin=msg.sender;
        contractNum=0;
    }
    //外部接口，分为注册、签署、查询
    //注册，传入用户想关联的以太坊地址和用户类型
    function signUp(address add,uint clientType,bytes32 id,bytes32 pubKey)public{
        if(isAlreadyRegistered(add,clientType)){
            return;//已经注册，不可以重复注册，应该通知传进来的那个函数，待补充
        }else if(clientType==1){//个人注册，type是1
            mapIndividual[add].isUsed=true;
            mapIndividual[add].ethAddress=add;
            mapIndividual[add].pid=id;
            mapIndividual[add].pubKey=pubKey;
        }else if(clientType==2){
            mapEnterprise[add].isUsed=true;
            mapEnterprise[add].ethAddress=add;
            mapEnterprise[add].eid=id;
            mapEnterprise[add].pubKey=pubKey;
        }
    }
    function isAlreadyRegistered(address add,uint clientType)returns(bool){
        if(clientType==1){
            return mapIndividual[add].isUsed;
        }else{
            return mapEnterprise[add].isUsed;
        }
    }
    function createAgreement(bytes32 contractID,address from, address to,string content) public returns(bool){
        //发布合同
        if(mapAgreement[contractID].isUsed){
            return;
        }else if(!mapIndividual[from].isUsed||!mapIndividual[to].isUsed){
            return;
        }else if(!mapEnterprise[from].isUsed||!mapEnterprise[to].isUsed){
            return;
        }
        //存入总表
        Agreement ag;
        ag.cid=contractID;
        ag.creater=from;
        ag.usrs[from]=1;ag.usrs[to]=2;
        ag.pri=ag.next=0;
        ag.agreementOriLink=content;
        mapAgreement[contractID]=ag;
        mapAgreement[contractID].isUsed=true;
        //存入创建者的甲方表
        if(mapIndividual[from].isUsed){
            mapIndividual[from].AAgreementIndexs.push(contractID);
        }else if(mapEnterprise[from].isUsed){
            mapEnterprise[from].AAgreementIndexs.push(contractID);
        }
        //存入乙方的乙方表
        if(mapIndividual[from].isUsed){
            mapIndividual[from].BAgreementIndexs.push(contractID);
        }else if(mapEnterprise[from].isUsed){
            mapEnterprise[from].BAgreementIndexs.push(contractID);
        }
        return true;
    }
    modifier onlySigned(){
        require(mapIndividual[msg.sender].isUsed==true||mapEnterprise[msg.sender].isUsed==true);
        _;
    }
    modifier cidValid(bytes32 cid){//确保合同有效且没过期
        require(mapAgreement[cid].isUsed==true&&mapAgreement[cid].next==0);
        _;
    }
    function signAgreementIndividual(bytes32 cid,string memory signedLink) public{
        //签署合同
        require(mapIndividual[msg.sender].isUsed==true,"user not exit");
        Individual storage individual=mapIndividual[msg.sender];
        require(individual.agrExsit[cid]==true,"This user don't have this agreement");
        Agreement storage agr=mapAgreement[cid];
        require(agr.next!=0,"This contract already out of date");
        agr.agreementSignedLink[msg.sender]=signedLink;
        
    }
    function signAgreementEnterprise(bytes32 cid,string memory signedLink) public{
        //签署合同
        require(mapIndividual[msg.sender].isUsed==true,"user not exit");
        Enterprise storage enterprise=mapEnterprise[msg.sender];
        require(enterprise.agrExsit[cid]==true,"This user don't have this agreement");
        Agreement storage agr=mapAgreement[cid];
        require(agr.next!=0,"This contract already out of date");
        agr.agreementSignedLink[msg.sender]=signedLink;
        
    }
    function comfirmAgreement(bytes32 cid)onlySigned() public{
        //确认合同
        require(mapAgreement[cid].usrs[msg.sender]!=0);
        mapAgreement[cid].agreed[msg.sender]=true;
    }
    function isSigned(address a)private returns(bool){
        return mapEnterprise[a].isUsed||mapIndividual[a].isUsed;
    }
    function changeAgreementContent(bytes32 oldCid,bytes32 cid,string agreementLink,address[]aParty,address[]bParty)onlySigned()public{
    //更新合同
        Agreement storage agreement=mapAgreement[oldCid];
        require(agreement.isUsed==true);
        require(agreement.creater==msg.sender);//合约创建者才能修改
        require(mapAgreement[cid].isUsed==false);//合约没被使用过
        Agreement newAgreement;
        newAgreement.cid=cid;
        newAgreement.creater=msg.sender;
        newAgreement.state=false;
        newAgreement.agreementOriLink=agreementLink;
        for(uint i=0;i<aParty.length;i++){
            require(isSigned(aParty[i]));
            newAgreement.usrs[aParty[i]]=1;
        }
        for(i=0;i<bParty.length;i++){
            require(isSigned(bParty[i]));
            newAgreement.usrs[bParty[i]]=2;
        }
        newAgreement.pri=agreement.cid;
        newAgreement.next=0;
        mapAgreement[cid]=newAgreement;
    }
    function querryForContract(bytes32 cid)constant public returns(string){
        require(mapAgreement[cid].usrs[msg.sender]!=0);
        return mapAgreement[cid].agreementOriLink;
        
    }
    function getPubKey(bytes32 cid,address requireAddress,bool isIndividual)onlySigned()cidValid(cid)public constant returns(bytes32){
        if(isIndividual){//确保已经注册
        require(mapIndividual[requireAddress].isUsed==true);
        }else{
        require(mapEnterprise[requireAddress].isUsed==true);
        }
        require(mapAgreement[cid].usrs[msg.sender]!=0&&mapAgreement[cid].usrs[requireAddress]!=0);
        if(isIndividual){
            return mapIndividual[requireAddress].pubKey;
        }else{
            return mapEnterprise[requireAddress].pubKey;
        }
    }
    function getPreContract(bytes32 cid)public constant returns(string){
    //获得更新之前的合同
        Agreement agr=mapAgreement[cid];
        require(agr.usrs[msg.sender]!=0&&agr.pri!=0);
        return mapAgreement[agr.pri].agreementOriLink;
    }
    function getEnterpriseInfo(address add)public constant returns(bytes32[]){
        require(mapEnterprise[add].isUsed==true);
        Enterprise ent=mapEnterprise[add];
        bytes32[] memory res=new bytes32[](9);
        res[0]=ent.leagalRepresentative;
        res[1]=ent.registerShare;
        res[2]=ent.fundTime;
        res[3]=ent.enterpriseType;
        res[4]=ent.registrar;
        res[5]=ent.endTime;
        res[6]=ent.service;
        res[7]=ent.eid;
        return res;
    }
}