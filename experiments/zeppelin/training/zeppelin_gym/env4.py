import logging
import math
import gym
from gym import spaces
from gym.utils import seeding
import numpy as np
import random
import polytope as pc

from polytope.solvers import lpsolve
def cheby_ball(poly1):
    #logger.debug('cheby ball')
    if (poly1._chebXc is not None) and (poly1._chebR is not None):
        # In case chebyshev ball already calculated and stored
        return poly1._chebR, poly1._chebXc
    if isinstance(poly1, pc.Region):
        maxr = 0
        maxx = None
        for poly in poly1.list_poly:
            rc, xc = cheby_ball(poly)
            if rc > maxr:
                maxr = rc
                maxx = xc
        poly1._chebXc = maxx
        poly1._chebR = maxr
        return maxr, maxx
    if pc.is_empty(poly1):
        return 0, None
    # `poly1` is nonempty
    r = 0
    xc = None
    A = poly1.A
    c = np.negative(np.r_[np.zeros(np.shape(A)[1]), 1])
    norm2 = np.sqrt(np.sum(A * A, axis=1))
    G = np.c_[A, norm2]
    h = poly1.b
    sol = lpsolve(c, G, h)
    #return sol
    if sol['status'] == 0 or (sol['status'] == 4 and pc.is_inside(poly1,sol['x'][0:-1])):
        r = sol['x'][-1]
        if r < 0:
            return 0, None
        xc = sol['x'][0:-1]
    else:
        # Polytope is empty
        poly1 = pc.Polytope(fulldim=False)
        return 0, None
    poly1._chebXc = np.array(xc)
    poly1._chebR = np.double(r)
    return poly1._chebR, poly1._chebXc


logger = logging.getLogger(__name__)

class ZeppelinEnv(gym.Env):
    """
    Agent is navigating a Zeppelin flying in the wind.
    The wind is composed of a wind field and a sudden turbulence.
    In particular, the agent is navigating near an obstacle which the agent must avoid.
    The goal of the agent is to leave the obstacle region.
    """

    metadata = {
        'render.modes': ['human', 'rgb_array'],
        'video.frames_per_second' : 60
    }

    def is_crash(self, some_state):
        x1 = some_state[0]
        x2 = some_state[1]
        c = some_state[2]
        return (-c < x1 and x1 < c) and (-c < x2 and x2 < c)
    
    def x1_min(self, state):
        x2 = state[1]
        c = state[2]
        w = state[3]
        return -(self.TIME_STEP * (self.MAX_VELOCITY + self.MAX_TURBULENCE) + ((self.MAX_VELOCITY - self.MAX_TURBULENCE) / w * (c - (x2 - self.TIME_STEP * (self.MAX_TURBULENCE + self.MAX_VELOCITY+w))) + c) )

    def x1_max(self, state):
        x2 = state[1]
        c = state[2]
        w = state[3]
        return self.TIME_STEP * (self.MAX_VELOCITY + self.MAX_TURBULENCE) + ((self.MAX_VELOCITY - self.MAX_TURBULENCE) / w * (c - (x2 - self.TIME_STEP * (self.MAX_TURBULENCE + self.MAX_VELOCITY+w))) + c)
    
    def x2_max(self, state):
        c = state[2]
        w = state[3]
        return c + w / (self.MAX_VELOCITY - self.MAX_TURBULENCE) * c + self.TIME_STEP * (self.MAX_VELOCITY + self.MAX_TURBULENCE + w)
    
    def x2_min(self, state):
        c = state[2]
        return -c - self.TIME_STEP * (self.MAX_VELOCITY + self.MAX_TURBULENCE)

    def reached_goal(self, state):
        # Goal is to leave obstacle region, i.e. achieve:
        # x2  <  -c2 - T * (p + r) |
        # x2 > c2 + w / (p - r) * c1 + T * (p + r + w) |
        # -x1 - T * (p + r) - ((p - r) / w * (c2 - (x2 - T * (r + p + w))) + c1) >= 0 |
        # x1 - T * (p + r) - ((p - r) / w * (c2 - (x2 - T * (r + p + w))) + c1) >= 0
        x1 = state[0]
        x2 = state[1]
        g1 = state[4]
        g2 = state[5]
        return np.min(np.abs(x1-g1) + np.abs(x2-g2)) < self.GOAL_RADIUS
        #return (x2 < self.x2_min(state) ) or \
        #        (x2 > self.x2_max(state) ) or \
        #        ( x1 <= self.x1_min(state)) or \
        #        ( x1 >= self.x1_max(state) )

    def __init__(self):
        # Makes the continuous fragment of the system determinitic by fixing the
        # amount of time that the ODE evolves.
        self.TIME_STEP = 0.5
        
        # Fallback controller works as follows:
        # For x1>0 we get the normal from the right triangle side
        # For x1<0 we get the normal from the left triangle side
        # For x1=0 we get the normal (0,1)
        # For which emergency value is the fallback controller activated?
        self.EMERGENCY_THRESHOLD = 0.95

        self.MIN_WIND_SPEED = 1.0
        self.MAX_WIND_SPEED = 30 # m/s in ~ 100 km/h
        self.MAX_TURBULENCE = 15 # m/s in ~ 54 km/h
        self.MAX_VELOCITY = 20 # m/s in ~ 72 km/h

        self.INCLUDE_UNWINNABLE=True

        self.FUEL_RESTRAINT = True
        self.REWARD_SCALE = 1e-1
        self.OBSTACLE_REWARD = -200.
        self.NO_FUEL_REWARD = -50.
        # done reward = (FUEL_RESTRAINT) ? r+fuel*r : 2*r
        self.DONE_REWARD = 100.
        self.TIME_STEP_REWARD = self.REWARD_SCALE

        self.MODEL_RESET_SHARE = 1.0
        self.POLYTOPES = None
        self.POLYTOPE_VOLUMES = None

        assert self.MAX_VELOCITY < self.MAX_TURBULENCE+self.MAX_WIND_SPEED
        assert self.MAX_TURBULENCE < self.MAX_VELOCITY

        self.MAX_X = 400 # m
        self.MIN_X = -400 # m
        self.MAX_Y = 400 # m
        self.MIN_Y = -400 # m

        self.WORST_CASE_TURBULENCE=False

        # self.MIN_C = 20 # m
        # self.MAX_C = 40 # m
        self.MIN_C = 10 # m
        self.MAX_C = 80 # m
        
        self.GOAL_RADIUS=40

        self.RENDER_ZEPPELIN_RADIUS=10
    
        # Action Space:
        #   - Speed \mu \in  [-1.0, 1.0]
        #   - Direction y1* \in  [-1.0, 1.0]
        #   - Emergeny e \in [0.0,1.0]
        # y2* direction is computed implicitly through y2 = sqrt(1-y1*^2)
        # Final velocity comptued through \mu*(y1*,y2*)
        action_low = np.array([-1.0, -1.0, 0.0])
        action_high = np.array([1.0,  1.0, 1.0])
        self.action_space = spaces.Box(action_low, action_high)

        # Observation Space:
        #   - Position x1 \in [MIN_X, MAX_X]
        #   - Position x2 \in [MIN_Y, MAX_Y]
        #   - Obstacle radius c \in [MIN_C, MAX_C]
        #   - Wind strength w \in [MIN_WIND_SPEED, MAX_WIND_SPEED]
        #   - Goal g1
        #   - Goal g2
        obs_low = np.array([
            self.MIN_X,
            self.MIN_Y,
            self.MIN_C,
            self.MIN_WIND_SPEED,
            self.MIN_X,
            self.MIN_Y
        ])
        obs_high = np.array([
            self.MAX_X,
            self.MAX_Y,
            self.MAX_C,
            self.MAX_WIND_SPEED,
            self.MAX_X,
            self.MAX_Y
        ])
        self.observation_space = spaces.Box(obs_low, obs_high)

        self._seed()
        self.viewer = None
        self.state = None

        self.steps_beyond_done = None

    def _seed(self, seed=None):
        self.np_random, seed = seeding.np_random(seed)
        return [seed]

    def step(self, action):
        return self._stepByModel(action)

    def _stepByModel(self, action):
        assert self.action_space.contains(action), "%s (of type %s) invalid" % (str(action), type(action))
        state = self.state

        # Compute turbulence
        z1 = 0.
        z2 = -1.
        if self.WORST_CASE_TURBULENCE:
            z1, z2 = self.get_worst_turbulence(self.state)
        else:
            z1_norm = self.np_random.uniform(low=-1.0, high=1.0, size=(1,))[0]
            z2_norm = np.sqrt(1-z1_norm**2)
            turbulence_strength = self.np_random.triangular(-self.MAX_TURBULENCE, 0.0 ,self.MAX_TURBULENCE, size=(1,))[0]
            z1 = z1_norm * turbulence_strength
            z2 = z2_norm * turbulence_strength

        x1 = state[0]
        x2 = state[1]
        c = state[2]
        w = state[3]
        g1 = state[4]
        g2 = state[5]

        self.steps+=1

        t = self.TIME_STEP
        
        if action[2] > self.EMERGENCY_THRESHOLD:
            if x1 == 0:
                y1=0.
                y2=1.
            else:
                t1,t2 = self.get_worst_turbulence(state)
                y1,y2 = -t1, -t2
        else:
            y_strength = np.clip(action[0], -1.0, 1.0)*self.MAX_VELOCITY
            y1_norm = np.clip(action[1], -1.0, 1.0)
            y2_norm = np.sqrt(1.01-0.9999*y1_norm**2) # numerical safeguard against negative sqrt
            y1 = 0.999949*y1_norm * y_strength
            y2 = y2_norm * y_strength

        x1_new = x1 + t*( y1 + z1 )
        x2_new = x2 + t*( y2 + z2 - w )
        
        self.state = (x1_new, x2_new, c, w,g1,g2)

        has_crashed = self.is_crash(self.state)
        reached_goal = self.reached_goal(self.state)
        done = has_crashed or reached_goal
        done = bool(done)

        # Imaginary fuel -> try to work as fast as possible
        fuel = 800-self.steps

        if has_crashed:
            # Penalize for crashing
            reward = self.OBSTACLE_REWARD
        elif reached_goal:
            reward = 2*self.DONE_REWARD
        elif fuel==0:
            # Do not run out of fuel
            reward = self.NO_FUEL_REWARD
        else:
            # Reward for not having crashed yet,
            # but dependent on efficiency
            reward = self.TIME_STEP_REWARD

        return np.array(self.state), reward, done, {'crash': has_crashed, 'goal': reached_goal}
    
    def is_in_bounds(self, state):
        w = state[3]
        c = state[2]
        x1 = state[0]
        x2 = state[1]
        intermediate_state1 = (None, None, c, w)
        if x2 < self.x2_min(intermediate_state1) or x2 > self.x2_max(intermediate_state1):
            #print("o", end="")
            return False
        intermediate_state2 = (None, x2, c, w)
        if x1 < self.x1_min(intermediate_state2) or x1 > self.x1_max(intermediate_state2):
            #print("o", end="")
            return False
        return True

    def random_reset(self):
        epsilon = 0.1
        w = self.np_random.uniform(low=(self.MAX_VELOCITY-self.MAX_TURBULENCE+epsilon), high=self.MAX_WIND_SPEED, size=(1,))[0]
        c = self.np_random.uniform(low=self.MIN_C, high=self.MAX_C, size=(1,))[0]
        intermediate_state1 = (None, None, c, w)
        x2 = self.np_random.uniform(low=self.x2_min(intermediate_state1), high=self.x2_max(intermediate_state1), size=(1,))[0]
        intermediate_state2 = (None, x2, c, w)
        x1 = self.np_random.uniform(low=self.x1_min(intermediate_state2), high=self.x1_max(intermediate_state2), size=(1,))[0]
        g1 = 0.0
        g2 = 0.0
        while self.exclude_because_unwinnable((g1,g2,c,w)):
            g1 = self.np_random.uniform(low=self.MIN_X, high=self.MAX_X, size=(1,))[0]
            g2 = self.np_random.uniform(low=self.MIN_Y, high=self.MAX_Y, size=(1,))[0]
        
        self.state = (x1,x2,c,w,g1,g2)
            
        return np.array(self.state)

    def exclude_because_unwinnable(self, state):
        """
        Returns True if state should be included, because setup is unwinnable (i.e. inside Bermuda triangle)
        """
        if self.INCLUDE_UNWINNABLE:
            return False
        x1 = state[0]
        x2 = state[1]
        c = state[2]
        w = state[3]
        x2_min = -c
        x2_max = (c + w / (self.MAX_VELOCITY - self.MAX_TURBULENCE) * c)
        x1_min = (- ((self.MAX_VELOCITY - self.MAX_TURBULENCE) / w * (c - x2) + c))
        x1_max = ( ((self.MAX_VELOCITY - self.MAX_TURBULENCE) / w * (c - x2) + c))
        if x1 > x1_min and x1 < x1_max and x2 > x2_min and x2 < x2_max:
            return True
        # If not above/below and not in bermuda triangle, we are out of danger
        return False
    
    def get_worst_turbulence(self, state):
        x1 = state[0]
        x2 = state[1]
        c = state[2]
        w = state[3]
        x2_min = -c
        x2_max = (c + w / (self.MAX_VELOCITY - self.MAX_TURBULENCE) * c)
        x1_min = (- ((self.MAX_VELOCITY - self.MAX_TURBULENCE) / w * (c - x2) + c))
        #x1_max = ( ((self.MAX_VELOCITY - self.MAX_TURBULENCE) / w * (c - x2) + c))
        gamma = self.MAX_TURBULENCE/np.sqrt(w**2+(self.MAX_VELOCITY - self.MAX_TURBULENCE)**2)
        if x2 <= x2_min:
            return 0., self.MAX_TURBULENCE
        elif x2 >= x2_max:
            return 0., -self.MAX_TURBULENCE
        elif x1 <= x1_min:
            return gamma*w, -gamma*(self.MAX_VELOCITY - self.MAX_TURBULENCE)
        else: # Assume x1 >= x1_max:
            return -gamma*w, -gamma*(self.MAX_VELOCITY - self.MAX_TURBULENCE)
    
    def model_reset(self):
        #print("m")
        while True:
            res = self.random_reset()
            if not self.is_crash(res) and not self.reached_goal(res) and not self.exclude_because_unwinnable(res):
                rv = res
                break
        return rv
    
    def reset(self):
        self.steps = 0
        r = self.np_random.uniform(low=0.0, high=1.0, size=(1,))[0]
        if r <= self.MODEL_RESET_SHARE:
            return self.model_reset()
        else:
            return self.polytope_reset()
            
    def init_polytopes(self, model_share, polytopes):
        self.MODEL_RESET_SHARE = model_share
        volume = []
        for p in polytopes:
            volume.append(pc.volume(p))
        total_volume = sum(volume)
        
        self.POLYTOPE_VOLUMES = [0]
        for v in volume:
            self.POLYTOPE_VOLUMES.append((self.POLYTOPE_VOLUMES[-1]*total_volume + v)/total_volume)
        self.POLYTOPES = []
        for p in polytopes:
            cheby_ball(p)
            self.POLYTOPES.append(p)

    def sample_from_poly(self):
        while True:
            #print(">", end="")
            r = self.np_random.uniform(low=0.0, high=1.0, size=(1,))[0]
            poly = self.POLYTOPES[-1]
            # TODO(steuber): Could be more efficient through binary search
            for i in range(len(self.POLYTOPE_VOLUMES)):
                if r > self.POLYTOPE_VOLUMES[i]:
                    poly = self.POLYTOPES[i-1]
            l_b, u_b = poly.bounding_box
            l_b = l_b.flatten()
            u_b = u_b.flatten()
            x = None
            n = poly.A.shape[1]
            for i in range(400):
                #print(".", end="")
                x = self.np_random.uniform(low=l_b,high=u_b,size=(n,))
                if x in poly:
                    break
            # Fallback if random sampling doesn't work
            if x is None:
                x = poly.chebXc
            # Fallback if polytope looks empty
            if x is None:
                continue
            return x
    
    def polytope_reset(self):
        while True:
            #print("|",end="")
            res = self.sample_from_poly()
            if not self.is_crash(res) and not self.reached_goal(res) and self.is_in_bounds(res) and not self.exclude_because_unwinnable(res):
                self.state = res
                rv = res
                break
        #print("")
        return rv




    def render(self, mode='human', close=False):
        if close:
            if self.viewer is not None:
                self.viewer.close()
                self.viewer = None
            return

        screen_width = 800
        screen_height = 800

        world_size_x = self.MAX_X - self.MIN_X
        world_size_y = self.MAX_Y - self.MIN_Y
        world_offset_x = -self.MIN_X
        world_offset_y = -self.MIN_Y
        scale_x = screen_width/world_size_x
        scale_y = screen_height/world_size_y
        from gym.envs.classic_control import rendering
        if self.viewer is None:
            self.viewer = rendering.Viewer(screen_width, screen_height)

            # Obstacle Circle
            obstacle = rendering.make_polygon([(-0.5,0.5),(0.5,0.5),(0.5,-0.5),(-0.5,-0.5)])
            obstacle.set_color(1.0, 0.0, 0.0)
            self.obstacletrans = rendering.Transform()
            obstacle.add_attr(self.obstacletrans)
            self.viewer.add_geom(obstacle)
            self.obstacletrans.set_translation(world_offset_x*scale_x, world_offset_y*scale_y)
            
            # Obstacle Circle
            goal = rendering.make_polygon([(-0.5,0.5),(0.5,0.5),(0.5,-0.5),(-0.5,-0.5)])
            obstacle.set_color(0.0, 1.0, 0.0)
            self.goaltrans = rendering.Transform()
            goal.add_attr(self.goaltrans)
            self.viewer.add_geom(goal)

            # Zeppelin
            zeppelin = rendering.make_circle(self.RENDER_ZEPPELIN_RADIUS*scale_x)
            zeppelin.set_color(0.0, 1.0, 1.0)
            self.zeppelintrans = rendering.Transform()
            zeppelin.add_attr(self.zeppelintrans)
            self.viewer.add_geom(zeppelin)

        if self.state is None: return None
        c=self.state[2]
        w=self.state[3]

        # Set Obstacle Size
        self.obstacletrans.set_scale(2*c*scale_x,2*c*scale_y)
        
        # Set goal size and pos
        self.obstacletrans.set_scale(2*self.GOAL_RADIUS*scale_x,2*self.GOAL_RADIUS*scale_y)
        self.obstacletrans.set_translation(float(world_offset_x+self.state[0])*scale_x, float(world_offset_y+self.state[1])*scale_y)

        # Set Zeppelin Position:
        x1 = float(self.state[0]+world_offset_x) * scale_x
        x2 = float(self.state[1]+world_offset_y) * scale_y

        # Create Obstacle Region
        x2_1 = self.x2_min(self.state)
        x2_2 = self.x2_max(self.state)

        x1_11 = scale_x*self.x1_min((None,x2_1,c,w))+world_offset_x
        x1_12 = scale_x*self.x1_max((None,x2_1,c,w))+world_offset_x
        x1_21 = scale_x*self.x1_min((None,x2_2,c,w))+world_offset_x
        x1_22 = scale_x*self.x1_max((None,x2_2,c,w))+world_offset_x
        x2_1 = scale_y*x2_1+world_offset_y
        x2_2 = scale_y*x2_2+world_offset_y
        o_region = rendering.make_polygon([(x1_11,x2_1),(x1_12,x2_1),(x1_22,x2_2),(x1_21,x2_2),(x1_11,x2_1)],filled=False)
        self.viewer.add_onetime(o_region)


        self.zeppelintrans.set_translation(x1, x2)

        return self.viewer.render(return_rgb_array = mode=='rgb_array')

gym.register(
      id='zeppelin-v4',
      entry_point=ZeppelinEnv,
      max_episode_steps=800,  # todo edit
      reward_threshold=400.0, # todo edit
  )