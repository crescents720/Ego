"""Author skeletal combat clips without altering either supplied source GLB.

Hotaru retains the existing rig/locomotion and gains finger hinges, Punch, Hit.
Zombie receives anatomical skin weights, an 18-joint rig and Idle/Walk/Bite/Hit.
Requires numpy and pygltflib; all animation is root-motion free.
"""
from pathlib import Path
import math
import numpy as np
from pygltflib import GLTF2, Node, Skin, Accessor, BufferView, Attributes, Animation, AnimationChannel, AnimationChannelTarget, AnimationSampler

ROOT=Path(__file__).resolve().parents[1]
def qmul(a,b):
    x,y,z,w=a;X,Y,Z,W=b
    return np.array([w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z])
def qinv(q):return np.array([-q[0],-q[1],-q[2],q[3]])/np.dot(q,q)
def from_to(a,b):
    a=a/np.linalg.norm(a);b=b/np.linalg.norm(b);q=np.r_[np.cross(a,b),1+np.dot(a,b)]
    if np.linalg.norm(q)<1e-8:return np.array([1.,0,0,0])
    return q/np.linalg.norm(q)
def euler(degrees):
    q=np.array([0.,0.,0.,1.])
    for axis,angle in zip(np.eye(3),degrees):
        r=math.radians(angle)/2;q=qmul(q,np.r_[axis*math.sin(r),math.cos(r)])
    return q
def qmat(q):
    x,y,z,w=q/np.linalg.norm(q)
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)], [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def matq(m):
    # Stable eigen decomposition, independent of quaternion sign.
    a=np.array([[m[0,0]-m[1,1]-m[2,2],m[1,0]+m[0,1],m[2,0]+m[0,2],m[2,1]-m[1,2]],
       [m[1,0]+m[0,1],m[1,1]-m[0,0]-m[2,2],m[2,1]+m[1,2],m[0,2]-m[2,0]],
       [m[2,0]+m[0,2],m[2,1]+m[1,2],m[2,2]-m[0,0]-m[1,1],m[1,0]-m[0,1]],
       [m[2,1]-m[1,2],m[0,2]-m[2,0],m[1,0]-m[0,1],m.trace()]])/3
    _,v=np.linalg.eigh(a);q=v[:,-1];return q if q[3]>=0 else -q

class Builder:
    def __init__(self,path):
        self.g=GLTF2().load(str(ROOT/path));self.blob=bytearray(self.g.binary_blob())
    def read(self,index):
        a=self.g.accessors[index];v=self.g.bufferViews[a.bufferView]
        dtype={5126:'<f4',5123:'<u2',5121:'u1',5125:'<u4'}[a.componentType]
        n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a.type]
        return np.ndarray((a.count,n),dtype=dtype,buffer=self.blob,offset=(v.byteOffset or 0)+(a.byteOffset or 0),strides=(v.byteStride or np.dtype(dtype).itemsize*n,np.dtype(dtype).itemsize)).copy()
    def add(self,values,kind,integer=False):
        a=np.asarray(values,dtype='<u2' if integer else '<f4')
        self.blob.extend(b'\0'*(-len(self.blob)%4));offset=len(self.blob);self.blob.extend(a.tobytes())
        self.g.bufferViews.append(BufferView(buffer=0,byteOffset=offset,byteLength=a.nbytes))
        ac=Accessor(bufferView=len(self.g.bufferViews)-1,componentType=5123 if integer else 5126,count=len(a),type=kind)
        if kind=='SCALAR':ac.min=[float(a.min())];ac.max=[float(a.max())]
        self.g.accessors.append(ac);return len(self.g.accessors)-1
    def globals(self):
        parent={c:i for i,n in enumerate(self.g.nodes) for c in n.children or []};cache={}
        def get(i):
            if i not in cache:
                n=self.g.nodes[i]
                if n.matrix:m=np.array(n.matrix).reshape(4,4).T
                else:
                    m=np.eye(4);m[:3,:3]=qmat(np.array(n.rotation or [0,0,0,1]))@np.diag(n.scale or [1,1,1]);m[:3,3]=n.translation or [0,0,0]
                cache[i]=get(parent[i])@m if i in parent else m
            return cache[i]
        return {i:get(i)for i in range(len(self.g.nodes))}
    def clip(self,name,times,poses,locations=None):
        rest=self.globals();animation=Animation(name=name,samplers=[],channels=[]);t=self.add(np.array(times).reshape(-1,1),'SCALAR')
        for j in self.g.skins[0].joints:
            node=self.g.nodes[j];base=np.array(node.rotation or [0,0,0,1]);global_q=matq(rest[j][:3,:3]);values=[]
            for pose in poses:
                value=pose.get(node.name,(0,0,0))
                delta=np.asarray(value) if len(value)==4 else euler(value)
                q=qmul(base,qmul(qmul(qinv(global_q),delta),global_q))
                q=q/np.linalg.norm(q)
                if values and np.dot(values[-1],q)<0:q=-q
                values.append(q)
            output=self.add(values,'VEC4');animation.samplers.append(AnimationSampler(input=t,output=output,interpolation='LINEAR'))
            animation.channels.append(AnimationChannel(sampler=len(animation.samplers)-1,target=AnimationChannelTarget(node=j,path='rotation')))
            positions=[]
            for k in range(len(times)):
                p=np.array(node.translation or [0,0,0],dtype=float)
                if locations:p+=locations[k].get(node.name,np.zeros(3))
                positions.append(p)
            output=self.add(positions,'VEC3');animation.samplers.append(AnimationSampler(input=t,output=output,interpolation='LINEAR'))
            animation.channels.append(AnimationChannel(sampler=len(animation.samplers)-1,target=AnimationChannelTarget(node=j,path='translation')))
            if node.name.startswith(('Fingers.','FingerTips.')):
                scales=[[1,1,1]for pose in poses]
                output=self.add(scales,'VEC3');animation.samplers.append(AnimationSampler(input=t,output=output,interpolation='LINEAR'))
                animation.channels.append(AnimationChannel(sampler=len(animation.samplers)-1,target=AnimationChannelTarget(node=j,path='scale')))
        for node_index,node in enumerate(self.g.nodes):
            if node.mesh is not None and self.g.meshes[node.mesh].weights:
                values=[[1.0 if name=='Punch' and 0<k<len(times)-1 else 0.0]for k in range(len(times))]
                output=self.add(values,'SCALAR');animation.samplers.append(AnimationSampler(input=t,output=output,interpolation='LINEAR'))
                animation.channels.append(AnimationChannel(sampler=len(animation.samplers)-1,target=AnimationChannelTarget(node=node_index,path='weights')))
        self.g.animations=[a for a in self.g.animations if a.name!=name]+[animation]
    def save(self,path):
        self.g.buffers[0].byteLength=len(self.blob);self.g.set_binary_blob(bytes(self.blob));self.g.save_binary(str(ROOT/path))

def hotaru():
    b=Builder('assets/characters/anime-girl/hotaru_animated.glb');g=b.g;skin=g.skins[0]
    # Correct the old approximate elbow/wrist landmarks before authoring fists.
    # Preserve mesh bind shape by rebuilding inverse bind matrices below.
    parents={c:i for i,n in enumerate(g.nodes)for c in n.children or []}
    corrected=[]
    for side,x in [('L',-1),('R',1)]:
        for name,point in [('Forearm',(x*.195,1.015,0)),('Hand',(x*.215,.865,.005))]:
            j=next(i for i,n in enumerate(g.nodes)if n.name==name+'.'+side)
            parent_world=b.globals()[parents[j]]
            g.nodes[j].translation=(np.linalg.inv(parent_world)@np.r_[point,1])[:3].tolist()
            corrected.append(j)
    for animation in g.animations:
        for channel in animation.channels:
            if channel.target.node in corrected and channel.target.path=='translation':
                sampler=animation.samplers[channel.sampler]
                sampler.output=b.add(np.tile(g.nodes[channel.target.node].translation,(len(b.read(sampler.input)),1)),'VEC3')
    # Collective finger hinges bend the distal hand geometry into a small fist.
    added=[]
    for side,x in [('L',-.212),('R',.212)]:
        parent=next(i for i,n in enumerate(g.nodes)if n.name=='Hand.'+side)
        for name,y in [('Fingers',.840),('FingerTips',.815)]:
            rest=b.globals();world=np.eye(4);world[:3,3]=(x,y,-.020)
            local=np.linalg.inv(rest[parent])@world
            node=Node(name=name+'.'+side,translation=local[:3,3].tolist(),rotation=matq(local[:3,:3]).tolist(),children=[])
            index=len(g.nodes);g.nodes.append(node);g.nodes[parent].children.append(index)
            skin.joints.append(index);added.append(index);parent=index
    rest=b.globals();ibm=np.array([np.linalg.inv(rest[j]).T.reshape(-1)for j in skin.joints]);skin.inverseBindMatrices=b.add(ibm,'MAT4')
    for mesh in g.meshes:
        for primitive in mesh.primitives:
            positions=b.read(primitive.attributes.POSITION);joints=b.read(primitive.attributes.JOINTS_0);weights=b.read(primitive.attributes.WEIGHTS_0)
            for side in ['L','R']:
                hand=next(k for k,j in enumerate(skin.joints)if g.nodes[j].name=='Hand.'+side)
                finger=next(k for k,j in enumerate(skin.joints)if g.nodes[j].name=='Fingers.'+side)
                tips=next(k for k,j in enumerate(skin.joints)if g.nodes[j].name=='FingerTips.'+side)
                arm_ids=[k for k,j in enumerate(skin.joints)if g.nodes[j].name in ['UpperArm.'+side,'Forearm.'+side,'Hand.'+side]]
                arm_mask=np.isin(joints,arm_ids)*weights
                for i in np.where(arm_mask.sum(axis=1)>.55)[0]:
                    p=positions[i];values={}
                    for name in ['UpperArm','Forearm','Hand']:
                        joint=next(k for k,j in enumerate(skin.joints)if g.nodes[j].name==name+'.'+side)
                        start=rest[skin.joints[joint]][:3,3]
                        end=rest[skin.joints[arm_ids[min(['UpperArm','Forearm','Hand'].index(name)+1,2)]]][:3,3] if name!='Hand' else np.array([start[0],.805,start[2]])
                        d=end-start;t=np.clip(np.dot(p-start,d)/max(np.dot(d,d),1e-9),0,1)
                        values[joint]=math.exp(-(np.linalg.norm(p-start-t*d)/.055)**2)+1e-8
                    pairs=list(values.items());total=sum(v for _,v in pairs)
                    joints[i]=[j for j,_ in pairs]+[0];weights[i]=[v/total for _,v in pairs]+[0]
                mask=(((joints==hand)*weights).sum(axis=1)>.20)&(positions[:,1]<.842)&(positions[:,1]>.77)
                for i in np.where(mask)[0]:
                    distal=float(np.clip((.835-positions[i,1])/.025,0,1));amount=float(np.clip((.845-positions[i,1])/.014,0,1))
                    original={int(j):float(w)*(1-amount)for j,w in zip(joints[i],weights[i])}
                    original[finger]=amount*(1-distal);original[tips]=amount*distal
                    pairs=sorted(original.items(),key=lambda item:-item[1])[:4];total=sum(v for _,v in pairs)
                    joints[i]=[j for j,_ in pairs]+[0]*(4-len(pairs));weights[i]=[v/total for _,v in pairs]+[0]*(4-len(pairs))
            primitive.attributes.JOINTS_0=b.add(joints,'VEC4',True);primitive.attributes.WEIGHTS_0=b.add(weights,'VEC4')
            # Compact the open neutral fingers into a fist before skinning. The
            # authored hand morph complements the arm rig at mobile distances.
            delta=np.zeros_like(positions)
            for side in ['L','R']:
                ids=[k for k,j in enumerate(skin.joints)if g.nodes[j].name in ['Hand.'+side,'Fingers.'+side,'FingerTips.'+side]]
                mask=((np.isin(joints,ids)*weights).sum(axis=1)>.2)&(positions[:,1]<.866)&(positions[:,1]>.77)
                center=np.array([-.212 if side=='L' else .212,.842,-.033 if side=='L' else -.006])
                for i in np.where(mask)[0]:
                    amount=float(np.clip((.866-positions[i,1])/.025,0,1))
                    closed=center+(positions[i]-center)*np.array([.85,.24,1.0])
                    delta[i]=(closed-positions[i])*amount
            primitive.targets=[Attributes(POSITION=b.add(delta,'VEC3'))]
        mesh.weights=[0.0];mesh.extras={'targetNames':['Fist']}
    # Existing locomotion clips must explicitly release the new finger joints.
    for animation in g.animations:
        duration=max(float(b.read(s.input).max())for s in animation.samplers)
        t=b.add([[0],[duration]],'SCALAR')
        for j in added:
            q=g.nodes[j].rotation
            out=b.add([q,q],'VEC4');animation.samplers.append(AnimationSampler(input=t,output=out,interpolation='LINEAR'))
            animation.channels.append(AnimationChannel(sampler=len(animation.samplers)-1,target=AnimationChannelTarget(node=j,path='rotation')))
            out=b.add([[1,1,1],[1,1,1]],'VEC3');animation.samplers.append(AnimationSampler(input=t,output=out,interpolation='LINEAR'))
            animation.channels.append(AnimationChannel(sampler=len(animation.samplers)-1,target=AnimationChannelTarget(node=j,path='scale')))
        for node_index,node in enumerate(g.nodes):
            if node.mesh is not None:
                out=b.add([[0],[0]],'SCALAR');animation.samplers.append(AnimationSampler(input=t,output=out,interpolation='LINEAR'))
                animation.channels.append(AnimationChannel(sampler=len(animation.samplers)-1,target=AnimationChannelTarget(node=node_index,path='weights')))
    fingers={name+'.'+side:(0,0,0)for name in ['Fingers','FingerTips']for side in ['L','R']}
    guard={**fingers,'Chest':(0,7,0),'UpperArm.L':(-65,0,8),'Forearm.L':(-70,0,0),'UpperArm.R':(-55,0,-8),'Forearm.R':(-80,0,0)}
    strike={**fingers,'Chest':(4,-9,0),'Pelvis':(0,-4,0),'UpperArm.L':(-60,0,10),'Forearm.L':(-75,0,0),'UpperArm.R':(-82,0,-6),'Forearm.R':(-5,0,0),'Hand.R':(-12,0,-5)}
    b.clip('Punch',[0,.10,.24,.31,.48,.62],[{},guard,strike,strike,guard,{}])
    recoil={'Chest':(-16,0,3),'Head':(-9,0,0),'UpperArm.L':(-40,0,12),'UpperArm.R':(-38,0,-12),'Forearm.L':(-48,0,0),'Forearm.R':(-50,0,0),'Pelvis':(-5,0,0)}
    b.clip('Hit',[0,.07,.17,.44],[{},recoil,recoil,{}])
    b.save('assets/characters/anime-girl/hotaru_combat.glb')
    print('Hotaru:',len(skin.joints),'joints;',[(a.name,len(a.channels))for a in g.animations])

def zombie():
    b=Builder('assets/characters/zombie/zombie.glb');g=b.g;defs=[
      ('Root',(0,0,0),None),('Pelvis',(0,.87,-.03),'Root'),('Chest',(0,1.17,-.01),'Pelvis'),('Neck',(0,1.35,.03),'Chest'),('Head',(-.014,1.43,.06),'Neck'),('Jaw',(-.014,1.36,.12),'Head'),
      ('UpperArm.L',(-.20,1.36,.02),'Chest'),('Forearm.L',(-.18,1.28,.25),'UpperArm.L'),('Hand.L',(-.10,1.28,.44),'Forearm.L'),
      ('UpperArm.R',(.20,1.36,.02),'Chest'),('Forearm.R',(.18,1.28,.25),'UpperArm.R'),('Hand.R',(.10,1.28,.44),'Forearm.R'),
      ('Thigh.L',(-.12,.86,-.15),'Pelvis'),('Shin.L',(-.20,.45,-.17),'Thigh.L'),('Foot.L',(-.245,.15,-.38),'Shin.L'),
      ('Thigh.R',(.11,.86,-.10),'Pelvis'),('Shin.R',(.13,.45,.16),'Thigh.R'),('Foot.R',(.205,.16,.25),'Shin.R')]
    origin={name:np.array(p)for name,p,_ in defs};indices={}
    for name,p,parent in defs:
        indices[name]=len(g.nodes);translation=origin[name]-(origin[parent]if parent else 0)
        g.nodes.append(Node(name=name,translation=translation.tolist(),children=[]))
        if parent:g.nodes[indices[parent]].children.append(indices[name])
    g.scenes[g.scene or 0].nodes.append(indices['Root']);g.skins=[Skin(name='ZombieCombatSkin',skeleton=indices['Root'],joints=list(indices.values()))]
    rest=b.globals();g.skins[0].inverseBindMatrices=b.add([np.linalg.inv(rest[j]).T.reshape(-1)for j in indices.values()],'MAT4')
    names=list(indices);joint_ids={n:i for i,n in enumerate(names)}
    def distance(p,a,c):
        d=c-a;t=np.clip(np.dot(p-a,d)/max(np.dot(d,d),1e-8),0,1);return np.linalg.norm(p-(a+t*d))
    for node in g.nodes:
        if node.mesh is None:continue
        node.skin=0
        for primitive in g.meshes[node.mesh].primitives:
            material=g.materials[primitive.material].name.lower();positions=b.read(primitive.attributes.POSITION);js=[];ws=[]
            for p in positions:
                side='L'if p[0]<0 else 'R'
                if material=='head':
                    jaw=float(np.clip((1.395-p[1])/.05,0,1)*np.clip((p[2]-.07)/.07,0,1))
                    weights={'Head':1-jaw,'Jaw':jaw}
                elif material=='hands':weights={'Hand.'+side:1}
                elif material=='boots':weights={'Foot.'+side:1}
                else:
                    if material=='pants':candidates=['Pelvis','Thigh.'+side,'Shin.'+side,'Foot.'+side]
                    elif p[1]>1.18 and (abs(p[0])>.15 or p[2]>.17):candidates=['Chest','UpperArm.'+side,'Forearm.'+side,'Hand.'+side]
                    else:candidates=['Pelvis','Chest','Neck']
                    weights={}
                    for name in candidates:
                        end=next((origin[n]for n,_,par in defs if par==name),origin[name]+np.array([0,.15,0]))
                        d=distance(p,origin[name],end);weights[name]=math.exp(-(d/.12)**2)+1e-7
                    if material=='pants':
                        # The waistband belongs to the pelvis, not the rotating
                        # thigh. Blend downward so the shirt/pants seam stays shut.
                        pelvic=float(np.clip((p[1]-.68)/.12,0,1))
                        limb_total=sum(w for n,w in weights.items()if n!='Pelvis')
                        weights={n:w/max(limb_total,1e-9)*(1-pelvic)for n,w in weights.items()if n!='Pelvis'}
                        weights['Pelvis']=pelvic
                pairs=sorted(weights.items(),key=lambda v:-v[1])[:4];total=sum(v for _,v in pairs)
                js.append([joint_ids[n]for n,_ in pairs]+[0]*(4-len(pairs)));ws.append([w/total for _,w in pairs]+[0]*(4-len(pairs)))
            primitive.attributes.JOINTS_0=b.add(js,'VEC4',True);primitive.attributes.WEIGHTS_0=b.add(ws,'VEC4')
    idle={'Chest':(0,0,1),'Head':(2,0,0)}
    b.clip('Idle',[0,1,2],[idle,{'Chest':(0,0,-1),'Head':(-2,0,0)},idle])
    # Foot targets drive the whole leg instead of adding tiny rotations to the
    # source's frozen wide stride. Stance speed .48/(.95*.6) matches .85 m/s.
    poses=[];locations=[];times=np.linspace(0,.95,25)
    for time in times:
        phase=float(time/.95);bounce=-.025+.010*(1-math.cos(phase*4*math.pi))
        pose={'Chest':(4,math.sin(phase*2*math.pi)*4,math.sin(phase*2*math.pi)*1.8),'Head':(-3,0,0),
              'UpperArm.L':(math.sin(phase*2*math.pi)*7,0,0),'UpperArm.R':(-math.sin(phase*2*math.pi)*7,0,0)}
        for side,shift in [('L',.5),('R',0)]:
            p=(phase+shift)%1
            if p<.6:z=.14-.48*p/.6;lift=0
            else:
                swing=(p-.6)/.4;z=-.34+.48*swing;lift=math.sin(math.pi*swing)*.15
            hip=origin['Thigh.'+side]+np.array([0,bounce,0])
            foot=origin['Foot.'+side].copy();foot[1]+=lift;foot[2]=z
            upper=origin['Shin.'+side]-origin['Thigh.'+side]
            lower=origin['Foot.'+side]-origin['Shin.'+side]
            l1=np.linalg.norm(upper);l2=np.linalg.norm(lower);offset=foot-hip;distance=np.linalg.norm(offset);axis=offset/distance
            along=(l1*l1-l2*l2+distance*distance)/(2*distance)
            bend=np.array([0,axis[2],-axis[1]]);bend/=np.linalg.norm(bend)
            knee=hip+axis*along+bend*math.sqrt(max(0,l1*l1-along*along))
            q1=from_to(upper,knee-hip);q2=from_to(lower,foot-knee)
            pose['Thigh.'+side]=q1
            pose['Shin.'+side]=qmul(qinv(q1),q2)
            pose['Foot.'+side]=qinv(q2)
        poses.append(pose);locations.append({'Pelvis':(0,bounce,0)})
    b.clip('Walk',times,poses,locations)
    wind={'Chest':(-6,0,0),'Head':(-8,0,0),'UpperArm.L':(-10,0,0),'UpperArm.R':(-10,0,0),'Forearm.L':(15,0,0),'Forearm.R':(15,0,0),'Jaw':(20,0,0)}
    grab={'Chest':(14,0,0),'Head':(8,0,0),'UpperArm.L':(-15,0,-5),'UpperArm.R':(-15,0,5),'Jaw':(23,0,0)}
    bite={'Chest':(32,0,0),'Head':(18,0,0),'UpperArm.L':(-15,0,-5),'UpperArm.R':(-15,0,5),'Jaw':(1,0,0)}
    b.clip('Bite',[0,.16,.32,.44,.60,.84],[{},wind,grab,bite,grab,{}],[{}, {}, {'Pelvis':(0,0,.18)}, {'Pelvis':(0,0,.42)}, {'Pelvis':(0,0,.18)}, {}])
    recoil={'Chest':(-10,0,2),'Head':(-12,0,0),'UpperArm.L':(-8,0,0),'UpperArm.R':(-8,0,0)}
    b.clip('Hit',[0,.06,.14,.30],[{},recoil,recoil,{}])
    b.save('assets/characters/zombie/zombie_combat.glb')
    print('Zombie:',len(defs),'joints;',[(a.name,len(a.channels))for a in g.animations])

if __name__=='__main__':hotaru();zombie()
